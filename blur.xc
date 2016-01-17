/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20600 - WEEKS 9 to 12
// ASSIGNMENT 3
// CODE SKELETON
// TITLE: "Concurrent Image Filter"
//
/////////////////////////////////////////////////////////////////////////////////////////

typedef unsigned char uchar;


#include <platform.h>
#include <stdio.h>
#include "pgmIO.h"

in port buttons = PORT_BUTTON;
out port cled[4] = {PORT_CLOCKLED_0,PORT_CLOCKLED_1,PORT_CLOCKLED_2,PORT_CLOCKLED_3};
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;

#define index(y, x) (y)*IMWD+(x)

//#define IMHT 256
//#define IMWD 16
//#define IMHT 16
#define TERMINATE 2000
#define PAUSE 2001
#define UNPAUSE 2002
#define RESTART 2003
#define CONTINUE 2004
#define MID_RESTART_SIGNAL 2
#define RESTART_SIGNAL 1
#define TERMINATE_SIGNAL 0
#define AUTO_CONTINUE_SIGNAL 4
#define RANDOM 223371398
#define workers 2 // Assume >= 2
#define MemoryLines (workers*5+2)
#define TotalMemory 21000 //(to be verified)


#define buttonA 14
#define buttonB 13
#define buttonC 11
#define buttonD 7


int min(int a, int b)
{
    return a < b? a : b;
}

void showLED(out port p, chanend fromOut, chanend control)
{
    unsigned int lightUpPattern;
    for (;;)
    {
        select
        {
        case fromOut :> lightUpPattern: //read LED pattern from visualiser process
            p <: lightUpPattern; //send pattern to LEDs
            break;
        case control :> lightUpPattern:
           return;
        default:
            break;
        }
    }
}

void waitMoment(uint myTime)
{
    timer tmr;
    unsigned int waitTime;
    tmr :> waitTime;
    waitTime += myTime;
    tmr when timerafter(waitTime) :> void;
}

void buttonListener(in port buttons, chanend toDistributor)
{
    int buttonInput; // Button pattern currently pressed
    int data, ok;
    for (;;)
    {
        toDistributor :> data;
        if (data == TERMINATE)
            return;
        buttonInput = 0;
        ok = 1;
        while (ok)
        {
            select
            {
            case buttons when pinsneq(15) :> buttonInput:
                if (buttonInput == buttonA || buttonInput == buttonB || buttonInput == buttonC || buttonInput == buttonD) //filter multiple button press
                {
                    printf("%d button\n", buttonInput);
                    toDistributor <: buttonInput;
                    ok = 0;
                }
                break;
            case toDistributor :> data:
                if (data==TERMINATE)
                    return;
                break;
            }
        }
        waitMoment(10000000);
    }
}

int DataInStream(char infname[], chanend c_out[], chanend control[], chanend IO, chanend toButtons, int autoReset, chanend toTiming)
{
    int dimensions; // The dimensions of the image being read in, in the binary format: wwwwwwwwwwwwwwwwhhhhhhhhhhhhhhhh
    int currentWorker = 0; // The worker to whom data is being sent
    int data; // A variable for receiving data from channels
    int lines; // The number of lines that will be processed by each worker; each worker will receive 'lines+2' lines
    int IMWD, IMHT; // The image dimensions
    uchar line[TotalMemory/MemoryLines]; // An array for holding the data read from the file

    printf("DataInStream: Start...\n");

    // Wait for button A to start processing; overwridden by autoReset (button D)
    if (!autoReset)
    {
        do
        {
            toButtons <: 1;
            toButtons :> data;
        } while (data != buttonA);
    }
    toButtons <: 1;

    // Start timing
    toTiming <: 1;

    // Open input image and read dimensions
    dimensions = _openinpgm(infname);
    if (dimensions == -1) // Handle file error
    {
        // Return from worker2's
        for (int i = 0; i < workers; i++)
            control[i] <: TERMINATE;

        // Return from buttonListner and DataOutStream
        toButtons <: TERMINATE;
        IO <: TERMINATE;
        return TERMINATE_SIGNAL;
    }
    IMWD = dimensions >> 16; // Extracts upper 16 bits
    IMHT = dimensions & 0xFFFF; // Extracts lower 16 bits

    // Sets the number of lines to be the lesser of the maximum amount of memory a worker *can* hold, and the amount of memory necessary for the entire image to be split equally into each worker
    lines = min(TotalMemory*5/MemoryLines/IMWD, IMHT/workers) - 2;

    // Send the image dimensions to the other processes
    IO <: IMWD;
    IO <: IMHT;
    for (int i = 0; i < workers; i++)
    {
        control[i] <: IMWD;
        control[i] <: IMHT;
    }

    // Main loop
    for (int y = 1; y <= IMHT; y++)
    {
        // Check for button input
        select
        {
        case toButtons :> data:
            // Handle pause
            if (data == buttonB)
            {
                // Send pause to DataOutStream
                IO <: PAUSE;

                // Wait for unpause
                do
                {
                    toButtons <: 1;
                    toButtons :> data;
                } while (data != buttonB);

                // Send unpause to DataOutStream
                IO <: UNPAUSE;
            }

            // Handle restart and termination
            else if (data == buttonA || data == buttonC)
            {
                // Return from worker2's
                for (int i = 0; i < workers; i++)
                    control[i] <: TERMINATE;

                // Return from buttonListner and DataOutStream
                toButtons <: TERMINATE;
                IO <: TERMINATE;

                if (data == buttonA) // Restart
                    return MID_RESTART_SIGNAL;
                return TERMINATE_SIGNAL; // Terminate
            }

            // Handle auto-reset toggle
            else if (data == buttonD)
                autoReset = !autoReset;

            // Request next button input
            toButtons <: 1;
            break;

        default:
            break;
        }

        // Read a line from the image
        _readinline(line, IMWD);

        // Switch to next worker after the two lines of overlap (the case of y=2 is an exception, there is no overlap)
        if (y%lines == 2 && y != 2)
            currentWorker = (currentWorker+1) % workers;

        // Send line read to worker /and/ next worker if within the overlap area (the case of y<2 is an exception, there is no overlap)
        if (y%lines < 2 && y >= 2)
            for (int x = 0; x < IMWD; x++)
            {
                c_out[currentWorker] <: line[x];
                c_out[(currentWorker+1)%workers] <: line[x];
            }

        // Send line to current worker
        else
            for(int x = 0; x < IMWD; x++)
                c_out[currentWorker] <: line[x];
    }

    // Close input image file
    _closeinpgm();

    // If auto-reset is enabled, return from buttonListener and start next blur iteration
    if (autoReset)
    {
        select
        {
        toButtons :> data:
            break;
        default:
            break;
        }
        toButtons <: TERMINATE;
        printf("DataInStream: Done...\n");
        return AUTO_CONTINUE_SIGNAL;
    }

    // Wait for restart or terminate to be specified
    do
    {
        toButtons :> data;
        toButtons <: 1;
    } while (data != buttonA && data != buttonC);

    // Return from button listener
    toButtons <: TERMINATE;

    printf("DataInStream:Done...\n");

    if (data == buttonA) // Restart
        return RESTART_SIGNAL;
    return TERMINATE_SIGNAL; // Terminate
}

void SetLEDs(chanend quadrants[], int ledsLit)
{
    int quadrant, remainder;
    quadrant = ledsLit/3;
    remainder = ledsLit % 3;

    // Clear all LEDs
    for (int i = 0; i < 4; ++i)
        quadrants[i] <: 0;

    // Set all quadrants before current level's quadrant
    for (int i = 0; i < quadrant; ++i)
        quadrants[i] <: 112;

    // Set all LEDs within current level's quadrant
    if (remainder == 1)
        quadrants[quadrant] <: 16;
    else if (remainder == 2)
        quadrants[quadrant] <: 48;
}

void DataOutStream(char outfname[], chanend c_in[], chanend IO, chanend quadrants[], chanend toTiming)
{
    int currentWorker = 0; // The worker to whom data is being sent
    int data; // A variable for receiving data from channels
    int lines; // The number of lines that will be processed by each worker; each worker will receive 'lines+2' lines
    int IMWD, IMHT; // The image dimensions
    int ledsLit = 0; // Used to send to SetLEDs as progress
    int counter = 0; // Used as a helper variable for ledsLit
    uchar line[TotalMemory/MemoryLines]; // An array for holding the data read from the file

    printf("DataOutStream:Start...\n");

    // Receive image dimensions from
    IO :> IMWD;
    IO :> IMHT;

    // Clear LEDs and set colour to red
    cledR <: 1;
    cledG <: 0;
    for (int i = 0; i < 4; ++i)
        quadrants[i] <: 0;

    // Sets the number of lines to be the lesser of the maximum amount of memory a worker *can* hold, and the amount of memory necessary for the entire image to be split equally into each worker
    lines = min(TotalMemory*5/MemoryLines/IMWD,IMHT/workers) - 2;

    // Open output image
    data = _openoutpgm(outfname, IMWD, IMHT);
    if (data)
    {
        printf("DataOutStream: Error opening %s\n.", outfname);
        return;
    }

    // Iteratively deals with 'lines' lines form each worker
    for (int y = 0; y < IMHT/lines; y++)
    {
        for (int i = 0; i < lines; ++i)
        {
            // Consider updating the LEDs
            if (counter*12/IMHT > ledsLit)
            {
                ledsLit = counter*12/IMHT;
                if (ledsLit > 12)
                    ledsLit = 12;
                SetLEDs(quadrants, ledsLit);
            }
            for (int x = 0; x < IMWD; x++)
                select
                {
                case IO :> data:
                    // Handle termination
                    if (data == TERMINATE)
                        return;
                    // Handle pause
                    if (data == PAUSE)
                        while (data != UNPAUSE)
                            IO :> data;
                    x--; // Make up for this iteration in the for loop
                    break;
                // Read output pixel from current worker into line buffer
                case c_in[currentWorker] :> line[x]:
                    break;
                }
            // Write out the line buffer
            _writeoutline(line, IMWD);
            ++counter;
        }

        // Next worker
        currentWorker = (currentWorker + 1) % workers;
    }

    // Deals with the remaining lines when they cannot be processed as 'lines' lines
    for (int y = 0; y < IMHT % lines; y++)
    {
        // Consider updating the LEDs
        if (counter*12/IMHT > ledsLit)
        {
            ledsLit = counter*12/IMHT;
            if (ledsLit > 12)
                ledsLit = 12;
            SetLEDs(quadrants, ledsLit);
        }
        for (int x = 0; x < IMWD; x++)
            select
            {
            case IO :> data:
                // Handle termination
                if (data == TERMINATE)
                    return;
                // Handle pause
                if (data==PAUSE)
                    while (data!=UNPAUSE)
                        IO :> data;
                x--; // Make up for this iteration in the for loop
                break;
            // Read output pixel from current worker into line buffer
            case c_in[currentWorker] :> line[x]:
                break;
            }
        // Write out the line buffer
        _writeoutline(line, IMWD);
        ++counter;
    }

    // Close output file
    _closeoutpgm();

    // Display all LEDs, and as green
    cledR <: 0;
    cledG <: 1;
    SetLEDs(quadrants, 12);

    // End timing
    toTiming <: 1;

    printf("DataOutStream: Done...\n");
    return;
}

void worker2(chanend dataIn, chanend dataOut, chanend control, int id)
{
    int IMHT, IMWD; // The image dimensions
    int lines; // The number of lines that will be processed by each worker; each worker will receive 'lines+2' lines
    uchar image[(TotalMemory*5)/MemoryLines];
    int sum; // A helper variable for holding the sum to send to DataOutStream
    int data; // A variable for receiving data from channels
    int start = id;

    // Retreive the image dimensions
    control :> IMWD;
    control :> IMHT;

    // Sets the number of lines to be the lesser of the maximum amount of memory a worker *can* hold, and the amount of memory necessary for the entire image to be split equally into each worker
    lines = min(TotalMemory*5/MemoryLines/IMWD, IMHT/workers) - 2;
    id *= lines; // The first of the current rows to process

    for (;;)
    {
        // Boundary check
        if (id > IMHT)
        {
            printf("worker %d DONE\n", start);
            return;
        }

        // Handle termination
        // This code will be copied and pasted throughout this function
        select                  //
        {                       //
        case control :> data:   //
            return;             //
        default:                //
            break;              //
        }                       //
        //////////////////////////

        // Handle the first row(s) of the image
        if (!id)
        {
            // Retreives the first 'lines+1' lines
            for (int i = 0; i < lines+1; i++)
                for (int j = 0; j < IMWD; j++)
                    select{case control :> data: return;
                    case dataIn :> image[index(i,j)]: break;}

            // Output the top edge of black border
            for (int i = 0; i < IMWD; i++)
                dataOut <: (uchar)0;

            select {case control :> data: return; default: break;}

            // Calculate average of 'lines-1' lines
            for (int i = 1; i < lines; i++)
            {
                select {case control :> data: return; default: break;}

                dataOut <: (uchar)0; // The black pixel on the far left
                // Calculate average of the 3x3 surrounding pixels and send to DataOutStream
                for (int j = 1; j < IMWD-1; j++)
                {
                    sum = image[index(i-1,j-1)] + image[index(i-1,j)] + image[index(i-1,j+1)] +
                        + image[index(i  ,j-1)] + image[index(i,  j)] + image[index(i,  j+1)] +
                        + image[index(i+1,j-1)] + image[index(i+1,j)] + image[index(i+1,j+1)];
                    sum /= 9;
                    dataOut <: (uchar)sum;
                }
                dataOut <: (uchar)0; // The black pixel on the far right
            }
        }

        // Handle the last few row(s) of the image
        else if (id+lines > IMHT)
        {
            // Retreives the number of lines remaining to process
            for (int i = 0; i < IMHT-id+1; i++)
                for (int j = 0; j < IMWD; j++)
                    select
                    {
                        case control :> data: return;
                        case dataIn :> image[index(i,j)]: break;
                    }

            // Calculate average of the remaining lines
            for (int i = 1; i < IMHT-id; i++)
            {
                dataOut <: (uchar)0; // The black pixel on the far left
                // Calculate average of the 3x3 surrounding pixels and send to DataOutStream
                for (int j = 1; j < IMWD-1; j++)
                {
                    sum = image[index(i-1,j-1)] + image[index(i-1,j)] + image[index(i-1,j+1)] +
                        + image[index(i  ,j-1)] + image[index(i,  j)] + image[index(i,  j+1)] +
                        + image[index(i+1,j-1)] + image[index(i+1,j)] + image[index(i+1,j+1)];
                    sum /= 9;
                    dataOut <: (uchar)sum;
                }
                dataOut <: (uchar)0; // The black pixel on the far right
            }
            for (int i = 0; i < IMWD; i++)
                dataOut <: (uchar)0;
            return;
        }

        // Handle the 'lines' lines of the image
        else
        {
            // Retreives the 'lines+2' lines
            for (int i = 0; i < lines+2; i++)
                for (int j = 0; j < IMWD; j++)
                    select
                    {
                        case control :> data: return;
                        case dataIn :> image[index(i,j)]: break;
                    }

            // Calculate average of 'lines' lines
            for (int i = 1; i < lines+1; i++)
            {
                select {case control :> data: return; default: break;}

                dataOut <: (uchar)0; // The black pixel on the far left
                // Calculate average of the 3x3 surrounding pixels and send to DataOutStream
                for (int j = 1; j < IMWD-1; j++)
                {
                    sum = image[index(i-1,j-1)] + image[index(i-1,j)] + image[index(i-1,j+1)] +
                        + image[index(i  ,j-1)] + image[index(i,  j)] + image[index(i,  j+1)] +
                        + image[index(i+1,j-1)] + image[index(i+1,j)] + image[index(i+1,j+1)];
                    sum /= 9;
                    dataOut <: (uchar)sum;
                }
                dataOut <: (uchar)0; // The black pixel on the far right
            }
        }
        // Increment id for next iteration of processing
        id += workers * lines;
    }
    printf("worker %d DONE\n", start);
    return;
}

void worker(chanend dataIn, chanend dataOut, chanend control, int id, chanend mainControl)
{
    // Handle termination/restart, signal received from main2
    for (;;)
    {
        int data;
        mainControl :> data;
        if (data == TERMINATE)
            return;
        worker2(dataIn, dataOut, control, id);
    }
}

void timing(chanend DataIn, chanend DataOut, chanend control)
{
    // Measure timing, won't go into details
    int data, counter = 0, time;
    timer tmr;
    tmr :> time;
    for (;;)
    {
        tmr :> time;
        time += 1000;
        tmr when timerafter(time) :> void;
        ++counter;
        select
        {
        case DataIn :> data:
            counter = 0;
            break;
        case DataOut :> data:
            printf("%d\n", counter);
            counter = 0;
            tmr :> time;
            time += 1000000;
            break;
        case control :> data:
            return;
        default:
            break;
        }
    }
}

int main2(chanend quadrants[], chanend qControl[], chanend wControl[], chanend wMainControl[], chanend c_inIO[], chanend c_outIO[], chanend TimeToIn, chanend TimeToOut, chanend TimeControl)
{
    int version = 0; // The current number used as suffix to the filename of the file being processed
    int restart = RESTART_SIGNAL; // Flag used as condition for starting next iteration of blurring
    int autoReset = 0; // Flag used for when button D is pressed to automatically continue to next blurring iteration without user intervention
    char infname[8], outfname[8]; // Filenames
    chan IO, buttonsDataIn;

    while (restart != TERMINATE_SIGNAL)
    {
        // Start workers
        for (int i = 0; i < workers; ++i)
            wMainControl[i] <: CONTINUE;

        // Initialise file names, by substituting version number into filename and incrementing for next version
        if (restart == RESTART_SIGNAL || restart == AUTO_CONTINUE_SIGNAL)
        {
            snprintf(infname, 8, "%d.pgm", version);
            version++;
            snprintf(outfname, 8, "%d.pgm", version);
        }

        // Set autoReset depending on the signal returned from DataInStream
        if (restart == AUTO_CONTINUE_SIGNAL)
            autoReset = 1;
        else
            autoReset = 0;

        // Start the main communication threads
        par
        {
            restart = DataInStream(infname, c_inIO, wControl, IO, buttonsDataIn, autoReset, TimeToIn);
            buttonListener(buttons, buttonsDataIn);
            DataOutStream(outfname, c_outIO, IO, quadrants, TimeToOut);
        }
    }

    // Terminate external processes: LED quadrants, workers and timer
    for (int i = 0; i < 4; ++i)
        qControl[i] <: TERMINATE;
    for (int i = 0; i < workers; ++i)
        wMainControl[i] <: TERMINATE;
    TimeControl <: TERMINATE;

    printf("Main: Done...\n");
    return 0;
}

int main()
{
    chan quadrants[4], qControl[4], wControl[workers], wMainControl[workers], c_inIO[workers], c_outIO[workers], TimeToIn, TimeToOut, TimeControl;
    par
    {
        par (int i = 0; i < 4; ++i)
        {
            on stdcore[i]: showLED(cled[i], quadrants[i], qControl[i]);
        }
        par (int i = 0; i < workers; i++)
        {
            on stdcore[i%3+1]: worker(c_inIO[i], c_outIO[i], wControl[i], i, wMainControl[i]);
        }
        on stdcore[0]: main2(quadrants, qControl, wControl, wMainControl, c_inIO, c_outIO, TimeToIn, TimeToOut, TimeControl);
        on stdcore[3]: timing(TimeToIn, TimeToOut, TimeControl);
    }

    return 0;
}
