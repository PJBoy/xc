#include <stdio.h>
#include <platform.h>

#define buttonA 14
#define buttonB 13
#define buttonC 11
#define buttonD 7
#define RESTORE_POSITION 100
#define RESET 13
#define PAUSE 12
#define UNPAUSE 12
#define TERMINATE -1024
#define masterReset 1023
#define endGame 1000
#define GREEN 1
#define RED 2
#define BUTTON 3

out port cled0 = PORT_CLOCKLED_0;
out port cled1 = PORT_CLOCKLED_1;
out port cled2 = PORT_CLOCKLED_2;
out port cled3 = PORT_CLOCKLED_3;
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;
out port bled = PORT_BUTTONLED;
in port buttons = PORT_BUTTON;
out port speaker = PORT_SPEAKER;

/////////////////////////////////////////////////////////////////////////////////////////
//
// Helper Functions provided for you
//
/////////////////////////////////////////////////////////////////////////////////////////

// Changes the colour of the (clock and button) LEDs
void LEDColour(chanend fromVisualiser, chanend fromController, chanend fromUser)
{
    for (;;)
    {
        int colour;
        select
        {
        case fromUser :> colour:
            if (colour == GREEN)
            {
                cledR <: 0;
                cledG <: 1;
            }
            else if (colour == RED)
            {
                cledG <: 0;
                cledR <: 1;
            }
            else if (colour == BUTTON)
            {
                // Changing colour of buttons, now ask which buttons
                fromUser :> colour;
                bled <: colour;
            }
            break;

        case fromVisualiser :> colour:
            if (colour == GREEN)
            {
                cledR <: 0;
                cledG <: 1;
            }
            else if (colour == RED)
            {
                cledG <: 0;
                cledR <: 1;
            }
            else if (colour == BUTTON)
            {
                // Changing colour of buttons, now ask which buttons
                fromVisualiser :> colour;
                bled <: colour;
            }
            break;

        case fromController :> colour:
            if (colour == TERMINATE)
                return;
            if (colour == GREEN)
            {
                cledR <: 0;
                cledG <: 1;
            }
            else if (colour == RED)
            {
                cledG <: 0;
                cledR <: 1;
            }
            else if (colour == BUTTON)
            {
                // Changing colour of buttons, now ask which buttons
                fromController :> colour;
                bled <: colour;
            }
            break;
        }
    }

    return;
}

// Displays an LED pattern in one quadrant of the clock LEDs
int showLED(out port led, chanend fromVisualiser, chanend fromController)
{
    unsigned int data;
    for (;;)
    {
        select
        {
            case fromVisualiser :> data:
                led <: data;
                break;

            case fromController :> data:
                if (data == TERMINATE)
                    return 0;
                led <: data;
                break;
        }
    }

    return 0;
}

// Translates position data and passes it to the LEDs
void visualiser(chanend fromUserAnt, chanend fromAttackerAnt, chanend toLEDColour, chanend toQuadrants[4])
{
    unsigned int data = 11;
    unsigned int userAntPosition = 11;
    unsigned int attackerAntPosition = 5;

    for (;;)
    {
        // Read given data.
        select
        {
        // User ant may give any of:
        //  The termination flag (if data == TERMINATE)
        //  Difficulty level (if data > 100)
        //  The restore position flag (if data == RESTORE_POSITION)
        //  User ant position (otherwise)
        case fromUserAnt :> data:
            if (data == TERMINATE)
                return;

            // Restore position just refreshes the display of the two ants.
            // Otherwise, save the new position of the user ant
            if (data != RESTORE_POSITION && data <= 100)
                userAntPosition = data;
            break;

        // Attacker ant will always give attacker ant position
        case fromAttackerAnt :> attackerAntPosition:
            break;
        }

        if (data > 100)
        {
            int level = data - 100;
            int quadrant = level/3;
            int remainder = level % 3;

            toLEDColour <: GREEN;

            // Clear all LEDs
            for (int i = 0; i < 4; ++i)
                toQuadrants[i] <: 0;

            // Set all quadrants before current level's quadrant
            for (int i = 0; i < quadrant; ++i)
                toQuadrants[i] <: 112;

            // Set all LEDs within current level's quadrant
            if (remainder == 1)
                toQuadrants[quadrant] <: 16;
            else if (remainder == 2)
                toQuadrants[quadrant] <: 48;
        }
        else
        {
            // The bits to set for the LED within the quadrant
            int j = 16<<(userAntPosition%3);
            int i = 16<<(attackerAntPosition%3);

            // The quadrant
            int jj = userAntPosition/3;
            int ii = attackerAntPosition/3;

            // Set the bits
            toLEDColour <: RED;
            toQuadrants[0] <: (j*(jj==0)) + (i*(ii==0));
            toQuadrants[1] <: (j*(jj==1)) + (i*(ii==1));
            toQuadrants[2] <: (j*(jj==2)) + (i*(ii==2));
            toQuadrants[3] <: (j*(jj==3)) + (i*(ii==3));
        }
    }

    return;
}

// Play a given audio wavelength
void playSound(chanend fromController, chanend fromButtonListener)
{
    for (;;)
    {
        timer tmr;
        int wavelength, t, isOn = 1;
        select
        {
        case fromController :> wavelength:
            if (wavelength == TERMINATE)
                return;

            tmr :> t;
            for (int i = 0; i < 2; ++i)
            {
                isOn = !isOn;
                t += wavelength;
                tmr when timerafter(t) :> void;
                speaker <: isOn;
            }
            break;

        case fromButtonListener :> wavelength:
            tmr :> t;
            for (int i = 0; i < 2; ++i)
            {
                isOn = !isOn;
                t += wavelength;
                tmr when timerafter(t) :> void;
                speaker <: isOn;
            }
            break;
        }
    }

    return;
}

// Read buttons to userAnt
void buttonListener(in port b, chanend audio, chanend toUserAnt)
{
    int r;
    for (;;)
    {
        // Wait for user's request for input (prevents such issues as duplicate inputs)
        toUserAnt :> r;
        if (r == TERMINATE)
            return;

        b when pinsneq(15) :> r; // Wait for a button to be pressed
        audio <: 2000000; // Buzz
        
        // Filter out simultaneous button presses
        if (r == buttonA || r == buttonB || r == buttonC || r == buttonD)
            toUserAnt <: r;
    }
    
    return;
}

// Wait function
void customWait(int time)
{
    timer tmr;
    unsigned int waitTime;
    tmr :> waitTime;
    waitTime += time;
    tmr when timerafter(waitTime) :> void;
    
    return;
}

// A nice value for customWait
void waitMoment()
{
    customWait(20000000);
    
    return;
}

// Controls how fast the attacker ant is
void waitLevel (chanend toAttacker, chanend toUser)
{
    int data;
    unsigned int level = 7; // Guaranteed to be >= 1
    for (;;)
    {
        select
        {
        // User may give any of:
        //  The termination flag (if data == TERMINATE)
        //  The reset flag (if data == RESET)
        //  1 or -1 to increase or decrease the difficulty, respectively
        case toUser :> data:
            if (data == TERMINATE)
                return;
            else if (data == RESET)
                level = 7;
            else
                level -= data;
            break;
        
        // Attacker requests pause, whose length is determined by the current level
        case toAttacker :> data:
            customWait(level * 5000000);
            toAttacker <: 1;
            break;
        }
    }

}


/////////////////////////////////////////////////////////////////////////////////////////
// RELEVANT PART OF CODE TO EXPAND FOR YOU
/////////////////////////////////////////////////////////////////////////////////////////


void userAnt(chanend fromButtons, chanend toVisualiser, chanend toController, chanend waitUser, chanend toLEDColour)
{
    for (;;)
    {
        int buttonInput; // Input from buttonListener
        int controllerData; // The verdict from the controller of if move is allowed, or the end game flag
        unsigned int userAntPosition = 11; // Initial defender position
        unsigned int attemptedAntPosition = 0; // The next attempted defender position after considering the button input
        int gameOver = 0; // When set, execute game over routine
        int startGame = 0; // When set, LEDs stop pulsing
        int reinitialise = 0; // When set, variables are given default values
        int level = 6; // Current difficult level, affects attacker ant, changed in pause routine

        // Display initial position
        toVisualiser <: userAntPosition;

        // Wait for user input
        fromButtons <: 1; // Ask for button input
        while (startGame != -1)
        {
            select
            {
            // If button input is given, let controller know
            case fromButtons :> buttonInput:
                startGame = 1;
                break;
                
            // Tell controller whether to stop pulsing (1) or not (0).
            // Once told to stop pulsing, break loop
            case toController :> buttonInput:
                toController <: startGame;
                startGame = 0 - startGame;
                break;
            }
        }

        // Start game
        while (!gameOver)
        {
            fromButtons <: 1; // Ask for button input
            
            select
            {
            // Handle termination signal
            case toController :> controllerData:
                if (controllerData == endGame)
                    gameOver = 1;
                break;

            // Read user input
            case fromButtons :> buttonInput:
                // Handle pause
                if (buttonInput == buttonB)
                {
                    toController <: PAUSE;

                    // Light up only buttons A, B and D
                    toLEDColour <: BUTTON;
                    toLEDColour <: 11;
                    
                    // Display current difficulty level
                    toVisualiser <: level+100;
                    
                    // Wait until (un)pause button is pressed
                    customWait(30000000); // Delay to give time for button release
                    fromButtons <: 1; // Ask for button input
                    fromButtons :> buttonInput;
                    while (buttonInput != buttonB)
                    {
                        // Decrease difficulty
                        if (buttonInput == buttonA && level > 1)
                        {
                            waitUser <: -1; // Update waitUser
                            --level; // Update userAnt
                            toVisualiser <: level+100; // Refresh LEDs
                        }
                        
                        // Increase difficulty
                        else if (buttonInput == buttonD && level < 12)
                        {
                            waitUser <: 1; // Update waitUser
                            ++level; // Update userAnt
                            toVisualiser <: level+100; // Refresh LEDs
                        }
                        
                        // Wait for next input
                        customWait(30000000); // Delay to give time for button release
                        fromButtons <: 1; // Ask for button input
                        fromButtons :> buttonInput;
                    }

                    // Show user the ant positions before we unpause
                    toVisualiser <: RESTORE_POSITION;
                    
                    // Light up only button B
                    toLEDColour <: BUTTON;
                    toLEDColour <: 2;

                    // Wait for unpause
                    customWait(30000000); // Delay to give time for button release
                    do
                    {
                        fromButtons <: 1; // Ask for button input
                        fromButtons :> buttonInput;
                    } while (buttonInput != buttonB);
                    customWait(30000000); // Delay to give time for button release

                    toController <: UNPAUSE;
                }

                // Handle reset
                else if (buttonInput == buttonC)
                {
                    customWait(30000000); // Delay to give time for button release
                    
                    // Reinitialise, end loop
                    reinitialise = 1;
                    gameOver = 1;

                    // Propagate reset signal
                    toController <: RESET;
                    waitUser <: RESET;
                }

                // Handle movement
                else
                {
                    // Clockwise
                    if (buttonInput == buttonA)
                        attemptedAntPosition = (userAntPosition + 1) % 12;
                    
                    // Anticlockwise
                    else if (buttonInput == buttonD)
                        attemptedAntPosition = (userAntPosition + 11) % 12;
                    
                    // Request new position
                    toController <: attemptedAntPosition;
                    toController :> controllerData;
                    
                    // If request granted, update and display position
                    if (!controllerData)
                    {
                        userAntPosition = attemptedAntPosition;
                        toVisualiser <: userAntPosition;
                    }
                }
                break;
            }
        }
        
        // If reinitialising, restart function
        if (reinitialise)
            continue;

        // User is given a chance to see their death, wait for button to be pressed
        waitMoment();
        fromButtons :> buttonInput;
        
        // Tell controller to flash LEDs
        toController <: 1;
        
        // Wait for LEDs to stop flashing
        toController :> controllerData;

        // Wait until user presses reset or terminate
        customWait(30000000); // Delay to give time for button release
        do
        {
            fromButtons <: 1; // Ask for button input
            fromButtons :> buttonInput;
        } while (buttonInput == buttonA || buttonInput == buttonD);

        // Handle termination
        if (buttonInput == buttonB)
        {
            // Propagate termination signal
            fromButtons <: TERMINATE;
            toVisualiser <: TERMINATE;
            toController <: TERMINATE;
            waitUser <: TERMINATE;
            
            return;
        }

        // Handle reset
        else
        {
            // Propagate reset signal
            toController <: RESET;
            waitUser <: RESET;
        } // And restart function
    }
}

void attackerAnt(chanend toVisualiser, chanend toController, chanend resetAttacker, chanend waitAttacker)
{
    for (;;)
    {
        int reset = 0; // When set, variables are given default values
        int waitConfirm; // When written, can make next move
        int moveCounter = 0; // Incremented with each move, is used for collisionless direction switching
        unsigned int attackerAntPosition = 5; // Initial attacker position
        unsigned int attemptedAntPosition; // The next attempted position after considering move direction
        int currentDirection = 1; // The current direction the attacker is moving
        int controllerData; // The verdict from the controller of if move is allowed, or the end game flag
        toVisualiser <: attackerAntPosition; // Display initial position

        while (!reset)
        {
            // Request new position
            attemptedAntPosition = attackerAntPosition + currentDirection;
            toController <: attemptedAntPosition;
            
            select
            {
            // Handle reset and termination flags
            case resetAttacker :> controllerData:
                // Handle reset
                if (controllerData == RESET)
                    reset = 1;

                // Handle termination
                else if (controllerData == TERMINATE)
                    return;
                break;

            // Handle movement
            case toController :> controllerData:
                // If request granted, update and display position
                if (!controllerData)
                {
                    attackerAntPosition = attemptedAntPosition;
                    toVisualiser <: attackerAntPosition;
                    
                    // Update move counter, and switch direction is a multiple of 31, 37 or 43
                    ++moveCounter;
                    if (!(moveCounter % 31) || !(moveCounter % 37) || !(moveCounter % 43))
                        currentDirection = 0 - currentDirection;
                }
                // Else, reverse direction
                else
                    currentDirection = 0 - currentDirection;
                    
                // Wait. Time spent waiting is determined by difficulty
                waitAttacker <: 1;
                waitAttacker :> waitConfirm;

                break;
            }
        }
    }
}

//COLLISION DETECTOR... the controller process responds to “permission-to-move” requests
// from attackerAnt and userAnt. The process also checks if an attackerAnt
// has moved to LED positions I, XII and XI.
void controller(chanend fromAttacker, chanend fromUser, chanend resetAttacker, chanend audio, chanend toLEDColour, chanend quadrants[4])
{
    for (;;)
    {
        unsigned int lastReportedUserAntPosition = 11; // Position last reported by userAnt
        unsigned int lastReportedAttackerAntPosition = 5; // Position last reported by attackerAnt
        unsigned int attempt = 0; // A requested position from the attacker or user, or a general signal
        int attackerWin = 0; // When set, execute game over routine
        int reinitialise = 0; // When set, variables are given default values
        int startGame; // When set, LEDs stop pulsing

        // Light up all buttons
        toLEDColour <: BUTTON;
        toLEDColour <: 15;

        // Pulse LEDs //
        do
        {
            // From red to green
            for (int i = 0; i < 1000; ++i)
            {
                // Amount of green will increase proportionally
                for (int ii = 0; ii < i; ++ii)
                {
                    toLEDColour <: GREEN;
                    quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112;
                }
                
                // Amount of red will increase proportionally
                for (int ii = i; ii < 1000; ++ii)
                {
                    toLEDColour <: RED;
                    quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112;
                }
            }
            
            // Ask user if button pressed yet
            fromUser <: 0;
            fromUser :> startGame;
            
            // If so, stop pulsing and start game
            if (startGame)
                break;
            
            // From green to red
            for (int i = 0; i < 1000; ++i)
            {
                // Amount of red will increase proportionally
                for (int ii = 0; ii < i; ++ii)
                {
                    toLEDColour <: RED;
                    quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112;
                }
                
                // Amount of green will increase proportionally
                for (int ii = i; ii < 1000; ++ii)
                {
                    toLEDColour <: GREEN;
                    quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112;
                }
            }
            
            // Ask user if button pressed yet
            fromUser <: 0;
            fromUser :> startGame;
        } while (!startGame); // If so, stop pulsing and start game


        // Traffic lights //
        // Light up no buttons
        toLEDColour <: BUTTON;
        toLEDColour <: 0;

        // Flash red and play a beep
        toLEDColour <: RED;
        quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112; // LEDs on
        for (int i = 300; i; --i) audio <: 70000; // Beep
        quadrants[0] <: 0; quadrants[1] <: 0; quadrants[2] <: 0; quadrants[3] <: 0; // LEDs off
        
        waitMoment();

        // Flash amber and play a beep
        // It is necessary to mix green and red in a ~4:1 ratio to produce yellow
        for (int i = 0; i < 20000; ++i) // With the beep
        {
            toLEDColour <: GREEN; quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112;
            toLEDColour <: GREEN; quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112;
            toLEDColour <: GREEN; quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112;
            toLEDColour <: GREEN; quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112;
            toLEDColour <: RED; quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112;
            if (!(i % 100)) audio <: 70000;
        }
        for (int i = 0; i < 10000; ++i) // Without the beep
        {
            toLEDColour <: GREEN;
            quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112;
            toLEDColour <: GREEN;
            quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112;
            toLEDColour <: GREEN;
            quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112;
            toLEDColour <: GREEN;
            quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112;
            toLEDColour <: RED;
            quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112;
        }
        quadrants[0] <: 0; quadrants[1] <: 0; quadrants[2] <: 0; quadrants[3] <: 0; // LEDs off
        waitMoment();

        // Flash green and play a beep
        toLEDColour <: GREEN;
        quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112; // LEDs on
        for (int i = 300; i; --i) audio <: 70000; // Beep
        quadrants[0] <: 0; quadrants[1] <: 0; quadrants[2] <: 0; quadrants[3] <: 0; // LEDs off
        waitMoment();

        // Light up all buttons
        toLEDColour <: BUTTON;
        toLEDColour <: 15;
        
        while (!attackerWin)
        {
            select
            {
            // Handle attacker's attempt
            case fromAttacker :> attempt:
                // Deny move if user in requested place
                if (attempt == lastReportedUserAntPosition)
                    fromAttacker <: 1;
                
                // Else:
                else
                {
                    // Grant move and update last reported position
                    fromAttacker <: 0;
                    lastReportedAttackerAntPosition = attempt;
                    
                    // Check for victory
                    if (attempt == 10 || attempt == 11 || !attempt)
                        attackerWin = 1;
                }
                break;

            // Handle user's attempt
            case fromUser :> attempt:
                // Handle pause
                if (attempt == PAUSE)
                {
                    fromUser :> attempt; // Wait until unpause
                    
                    // Light up all buttons
                    toLEDColour <: BUTTON;
                    toLEDColour <: 15;
                }
                
                // Handle reset
                else if (attempt == RESET)
                {
                    // Reinitialise, end loop
                    reinitialise = 1;
                    attackerWin = 1;
                    
                    // Propagate reset to attacker
                    fromAttacker :> attempt;
                    resetAttacker <: RESET;
                }
                
                // Deny move if attacker in requested place
                else if (attempt == lastReportedAttackerAntPosition)
                    fromUser <: 1;
                
                // Else: grant move and update last reported position
                else
                {
                    fromUser <: 0;
                    lastReportedUserAntPosition = attempt;
                }
                break;
            }
        }
        
        // If reinitialising, restart function
        if (reinitialise)
            continue;

        // Tell user game is over
        fromUser <: endGame;

        // Make an extremely pleasant noise, won't go into details
        for (int j = 0; j < 5; ++j)
        {
            for (int jj = 20000+j*10000; jj > 1000+j*10000; jj -= 80+j*20)
                audio <: jj;
            for (int jj = 1000+j*10000; jj < 20000+(j+1)*10000; jj += 50+j*60)
                audio <: jj;
        }

        // Wait for button to be pressed
        fromUser :> attempt;

        // Flash the LEDs
        for (int i = 0; i < 3; ++i)
        {
            quadrants[0] <: 0; quadrants[1] <: 0; quadrants[2] <: 0; quadrants[3] <: 0;
            waitMoment();
            quadrants[0] <: 112; quadrants[1] <: 112; quadrants[2] <: 112; quadrants[3] <: 112;
            waitMoment();
        }

        // Light up only buttons B and C
        toLEDColour <: BUTTON;
        toLEDColour <: 6;
        
        // Tell user LEDs have stopped flashing
        fromUser <: 1;
        
        // Receive signal from user
        fromUser :> attempt;
        
        // Handle termination
        if (attempt == TERMINATE)
        {
            // Propagate termination signal
            fromAttacker :> attempt;
            resetAttacker <: TERMINATE;
            quadrants[0] <: TERMINATE;
            quadrants[1] <: TERMINATE;
            quadrants[2] <: TERMINATE;
            quadrants[3] <: TERMINATE;
            audio <: TERMINATE;
            toLEDColour <: TERMINATE;
            return;
        }

        // Handle reset
        // Propagate reset signal
        fromAttacker :> attempt;
        resetAttacker <: RESET;
        // And restart function
    }
}

//MAIN PROCESS defining channels, orchestrating and starting the processes
int main()
{
    chan buttonsToUserAnt, // From buttonListener to userAnt
    userAntToVisualiser, // From userAnt to Visualiser
    attackerAntToVisualiser, // From attackerAnt to Visualiser
    attackerAntToController, // From attackerAnt to Controller
    userAntToController, // From userAnt to Controller
    quadrantsVisualiser[4], quadrantsController[4], // From Visualiser and Controller to showLEDs
    resetAttacker, // From Controller to attackerAnt
    audioController, audioButtonListener, // From Controller and buttonListener to playSound
    colourVisualiser, colourController, colourUser, // From Visualiser, Controller and userAnt to LEDColour
    waitUser, waitAttacker; // From userAnt and attackerAnt to waitLevel

    par
    {
        //PROCESSES FOR YOU TO EXPAND
        on stdcore[1]: userAnt(buttonsToUserAnt, userAntToVisualiser, userAntToController, waitUser, colourUser);
        on stdcore[2]: attackerAnt(attackerAntToVisualiser, attackerAntToController, resetAttacker, waitAttacker);
        on stdcore[3]: controller(attackerAntToController, userAntToController, resetAttacker, audioController, colourController, quadrantsController);

        //HELPER PROCESSES
        on stdcore[0]: LEDColour(colourVisualiser, colourController, colourUser);
        on stdcore[0]: playSound(audioController, audioButtonListener);
        on stdcore[0]: buttonListener(buttons, audioButtonListener, buttonsToUserAnt);
        on stdcore[0]: visualiser(userAntToVisualiser, attackerAntToVisualiser, colourVisualiser, quadrantsVisualiser);
        on stdcore[0]: showLED(cled0, quadrantsVisualiser[0], quadrantsController[0]);
        on stdcore[1]: showLED(cled1, quadrantsVisualiser[1], quadrantsController[1]);
        on stdcore[2]: showLED(cled2, quadrantsVisualiser[2], quadrantsController[2]);
        on stdcore[3]: showLED(cled3, quadrantsVisualiser[3], quadrantsController[3]);
        on stdcore[3]: waitLevel(waitAttacker, waitUser);
    }
    return 0;
}
