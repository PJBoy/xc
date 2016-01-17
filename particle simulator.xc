#include <stdio.h>
#include <platform.h>

out port cled[4] = {PORT_CLOCKLED_0,PORT_CLOCKLED_1,PORT_CLOCKLED_2,PORT_CLOCKLED_3};
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;
in port buttons = PORT_BUTTON;
out port speaker = PORT_SPEAKER;

#define noParticles 12
#define STARTINACTIVE 112
#define STARTACTIVE 111
#define TERMINATE 101
#define PAUSE 102
#define UNPAUSE 104
#define RESET 103
#define CHANGEVELOCITY 113
#define REQUESTVELOCITY 105
#define OK 106
#define NO 107
#define REQ 108
#define APPROVE 109
#define SOUND 110
#define buttonA 14
#define buttonB 13
#define buttonC 11
#define buttonD 7
#define TIME 1000000
#define debug 0

//DISPLAYS an LED pattern in one quadrant of the clock LEDs
void showLED(out port p, chanend fromVisualiser)
{
    unsigned int lightUpPattern;
    unsigned int running = 1;
    while (running)
    {
        select
        {
         case fromVisualiser :> lightUpPattern: //read LED pattern from visualiser process
             if (lightUpPattern == TERMINATE)
                 return;
             p <: lightUpPattern; //send pattern to LEDs
             break;
         default:
             break;
        }
    }
}

//PLAYS a short sound (pls use with caution and consideration to other students in the labs!)
void playSound(unsigned int wavelength, int duration, out port speaker)
{
    timer tmr;
    int t, isOn = 1;
    tmr :> t;
    for (int i = 0; i < duration; ++i)
    {
        isOn = !isOn;
        t += wavelength;
        tmr when timerafter(t) :> void;
        speaker <: isOn;
    }
}

//WAIT function
void waitMoment(uint myTime)
{
    timer tmr;
    unsigned int waitTime;
    tmr :> waitTime;
    waitTime += myTime;
    tmr when timerafter(waitTime) :> void;
}
//pause functon pauses particle 'jon'. Since we pause the particles from 1 to 10 and to avoid deadlock, particle 'jon+1' is paused as well
void pause(int jon, chanend show[], unsigned int display[], chanend toQuadrant[])
{
	int i=13,data,k,q,j;
	select
	{
		case show[(jon+1)%12] :> data:
			show[(jon+1)%12] <: PAUSE;
			i=(jon+1)%12;
			if (data==1||data==-1)
			{
				display[(i+data+12) % 12] = (i+data+12) % 12;
				display[i] = 13;
				for (q = 0; q < 4; ++q)
				{
					j = 0; for (k = 0; k < noParticles; ++k) if (display[k] != 13) j += (16 << display[k]%3) * (display[k]/3 == q); toQuadrant[q] <: j;
				}
			}
			break;
		default:
			break;
	}
	select
	{
		case show[jon] :> data:
			i=jon;
			show[i] <: PAUSE;
			if (data==1||data==-1)
			{
				display[(i+data+12) % 12] = (i+data+12) % 12;
				display[i] = 13;
				for (q = 0; q < 4; ++q)
				{
					j = 0; for (k = 0; k < noParticles; ++k) if (display[k] != 13) j += (16 << display[k]%3) * (display[k]/3 == q); toQuadrant[q] <: j;
				}
			}
			break;
		default:
			break;
	}
}

//PROCESS TO COORDINATE DISPLAY of LED Particles
void visualiser(chanend toButtons, chanend show[], chanend toQuadrant[], out port speaker)
{
    for (;;)
    {

        unsigned int display[noParticles];
        unsigned int running = 1;
        int j, i;
        int data;
        int sound = 0;
        int state = OK; // OK or PAUSE

        cledR <: 1;
        // Initial Display
        toQuadrant[0] <: 64;
        toQuadrant[1] <: 64;
        toQuadrant[2] <: 0;
        toQuadrant[3] <: 64;
        for (j = 0; j < 12; ++j)
            display[j] = 13;

        // Wait for 1st buttonA input
        do
        {
            toButtons <: 1;
            toButtons :> data;
        } while (data != buttonA);
        // Acitvate particles
        for (int k = 0; k < 12; ++k)
            show[k] <: 1;

        // Request button input and start the running loop
        toButtons <: 1;
        while (running)
        {

            i=13;
            select //check which particle has a message to transmit
            {
                case show[0] :> data:
                    i=0;
                    break;
                case show[1] :> data:
                    i=1;
                    break;
                case show[2] :> data:
                    i=2;
                    break;
                case show[3] :> data:
                    i=3;
                    break;
                case show[4] :> data:
                    i=4;
                    break;
                case show[5] :> data:
                    i=5;
                    break;
                case show[6] :> data:
                    i=6;
                    break;
                case show[7] :> data:
                    i=7;
                    break;
                case show[8] :> data:
                    i=8;
                    break;
                case show[9] :> data:
                    i=9;
                    break;
                case show[10] :> data:
                    i=10;
                    break;
                case show[11] :> data:
                    i=11;
                    break;
                default:
                    break;
            }
            // Status is requested from particle
            if (i!=13)
            {
               if (data == REQ)
                   show[i] <: state;
               // Play collision sound
               else if (data == SOUND)
                   playSound(20000, 20, speaker);
               // Update display
               else
               {

                   display[(i+data+12) % 12] = (i+data+12) % 12;
                   display[i] = 13;
                   for (int q = 0; q < 4; ++q)
                   {
                       j = 0; for (int k = 0; k < noParticles; ++k) if (display[k] != 13) j += (16 << display[k]%3) * (display[k]/3 == q); toQuadrant[q] <: j;
                   }
               }
            }

            select //check if the buttonListener wants to send something; also handle input within select
            {
                case toButtons :> data:
                    if (state == OK)
                    {
                        if (data == buttonB)
                        {	//pause every particle
                            for (i=0;i<12;i++)
                            {
                                waitMoment(20*TIME);
                                pause(i, show,display,toQuadrant);
                            }
                            state = PAUSE;
                        }

                        else if (data == buttonC)
                        {
                            // Send terminate to all particles
                            for (i = 0; i < 12; ++i)
                            {
                                waitMoment(TIME);
                                select
                                {
                                    case show[i] :> data:
                                        show[i] <: TERMINATE;
                                        break;
                                    default:
                                        show[i] <: TERMINATE;
                                        break;
                                }
                            }
                            // Send terminate to button listener and LEDs
                            toButtons <: TERMINATE;
                            toQuadrant[0] <: TERMINATE; toQuadrant[1] <: TERMINATE; toQuadrant[2] <: TERMINATE; toQuadrant[3] <: TERMINATE;
                            return;
                        }
                    }
                    else
                    {
                        // Unpause
                        if (data == buttonA)
                        {
                            // Send unpause to particles
                            for (i = 0; i < 12; ++i)
                            {
                                select
                                {
                                case show[i] :> data:
                                    //if (data == REQ)
                                        show[i] <: UNPAUSE;
                                    break;
                                default:
                                    show[i] <: UNPAUSE;
                                    break;
                                }
                            }
                            state = OK;
                        }

                        // Reset
                        else if (data == buttonB)
                        {	//reset all particles to their original state
                            for (i = 0; i < 12; ++i)
                                show[i] <: RESET;
                            running = 0;
                            break;
                        }

                        // Terminate
                        else if (data == buttonC)
                        {
                            // Send terminate to particles
                            for (i = 0; i < 12; ++i) select
							{
								case show[i] :> data:
									if (data==REQ)
										show[i] <: TERMINATE;
									break;
								default:
									show[i] <: TERMINATE;
									break;
							}


                            // Send terminate to button listener and LEDs
                            toButtons <: TERMINATE;
                            toQuadrant[0] <: TERMINATE; toQuadrant[1] <: TERMINATE; toQuadrant[2] <: TERMINATE; toQuadrant[3] <: TERMINATE;
                            return;
                        }

                        // Particle edit menu
                        if (data == buttonD)
                        {
                            int currentParticle = 0;
                            int currentParticleQ = 0;
                            int currentParticleV = 16;
                            int flashing = 1;
                            int menu = 1;
                            cledR <: 0;
                            cledG <: 1;
                            // Light up particles
                            // Flash current position
                            // Get button input
                            //  Exit with A
                            //  Left/right with B/C
                            //  Add/select with D
                            //   Add creates a new particle at current position
                            //   Select chooses particle at current position for speed increasing
                            //    A speed of zero will delete the particle
                            while (menu)
                            {
                                toButtons <: 1;
                                flashing = 1;
                                while (flashing)
                                {
                                    select
                                    {
                                    case toButtons :> data:
                                        flashing = 0;
                                        break;
                                    default:
                                    	//make the current position flash to indicate where you are
                                        for (int q = 0; q < 4; ++q)
                                        {
                                            j = 0;
                                            for (int k = 0; k < noParticles; ++k)
                                            {
                                                if (display[k] != 13)
                                                    j ^= (16 << display[k]%3) * (display[k]/3 == q);
                                                if (k == currentParticle)
                                                    j ^= (16 << k%3) * (k/3 == q);
                                            }
                                            toQuadrant[q] <: j;
                                        }
                                        waitMoment(TIME*50);
                                        for (int q = 0; q < 4; ++q)
                                        {
                                            j = 0;
                                            for (int k = 0; k < noParticles; ++k)
                                                if (display[k] != 13)
                                                    j += (16 << display[k]%3) * (display[k]/3 == q);
                                            toQuadrant[q] <: j;
                                        }
                                        waitMoment(TIME*50);
                                        break;
                                    }
                                }
                                if (data == buttonA)
                                    menu = 0; //resume to game
                                else if (data == buttonB) //move left
                                {
                                    currentParticle = (currentParticle+11) % 12;
                                    currentParticleQ = currentParticle / 3;
                                    currentParticleV = currentParticle % 3;
                                }
                                else if (data == buttonC) //move right
                                {
                                    currentParticle = (currentParticle+1) % 12;
                                    currentParticleQ = currentParticle / 3;
                                    currentParticleV = currentParticle % 3;
                                }
                                else if (data == buttonD) //add particle (if that position is inactive or go in the speed menu if active
                                {
                                    if (display[currentParticle] == 13)//activate particle
                                    {
                                        show[currentParticle] <: STARTACTIVE;
                                        display[currentParticle] = currentParticle;
                                    }
                                    else //change speed
                                    {
                                        int levelSelect = 1;
                                        int levelShow = 1;
                                        int level,quadrant,remainder;
                                        show[currentParticle] <: REQUESTVELOCITY;
                                        show[currentParticle] :> level;
                                        while (levelSelect)
                                        {
                                            toButtons <: 1;
                                            levelShow = 1;
                                            while (levelShow)
                                            {
                                                select
                                                {
                                                case toButtons :> data:
                                                    levelShow = 0;
                                                    break;
                                                default:
                                                    quadrant = level/3;
                                                    remainder = level % 3;

                                                    // Clear all LEDs
                                                    for (int i = 0; i < 4; ++i)
                                                        toQuadrant[i] <: 0;

                                                    // Set all quadrants before current level's quadrant
                                                    for (int i = 0; i < quadrant; ++i)
                                                        toQuadrant[i] <: 112;

                                                    // Set all LEDs within current level's quadrant
                                                    if (remainder == 1)
                                                        toQuadrant[quadrant] <: 16;
                                                    else if (remainder == 2)
                                                        toQuadrant[quadrant] <: 48;
                                                    break;
                                                }
                                            }
                                            if (data == buttonA) //resume from speed menu
                                                levelSelect = 0;
                                            else if (data == buttonB && level != 12) //change level
                                                --level;
                                            else if (data == buttonC && level != 0) //change leve
                                                ++level;
                                        }
                                        if (level) //sending message to particle about changing its speed
                                        {
                                            show[display[currentParticle]] <: CHANGEVELOCITY;
                                            show[display[currentParticle]] <: level;
                                        }
                                        else //deactivating a particle
                                            show[display[currentParticle]] <: STARTINACTIVE;
                                    }
                                }
                            }
                            cledR <: 1;
                            cledG <: 0;
                        }
                    }
                    toButtons <: 1;
                    break;
                default:
                    break;
            }
        }
    }
}

//READ BUTTONS and send commands to Visualiser, delay issue can be fixed by mask communication
void buttonListener(in port buttons, chanend toVisualiser)
{
    int buttonInput; // Button pattern currently pressed
    unsigned int running = 1; // Helper variable to determine system shutdown
    int data;
    while (running)
    {
        toVisualiser :> data;
        waitMoment(10000000);
        if (data == TERMINATE)
            return;
        buttonInput = 0;
        for (;;)
        {
            buttons when pinsneq(15) :> buttonInput;
            if (buttonInput == buttonA || buttonInput == buttonB || buttonInput == buttonC || buttonInput == buttonD) //filter multiple button press
            {
                printf("%d button\n",buttonInput);
                toVisualiser <: buttonInput;
                break;
            }
        }
    }
}

//This is some kind of custom waitMoment. The particle is inactive but it can give feedback to its neighbours
int interactWait(chanend left, chanend right,chanend toVisualiser, int myTime,int &currentVelocity,int &currentDirection)
 {

	 int stop=0,newVelocity,newDirection;
	 for (int asd=1;asd<=myTime;asd++)
	 {
		 select
	 	 {
	 		 case left :> newDirection:
	 			 left :> newVelocity;
	 		 	 left <: NO;
	 		 	 left <: currentDirection;
	 		 	 left <: currentVelocity;
	 		 	 currentDirection=newDirection;
	 		 	 currentVelocity=newVelocity;
	 		 	 toVisualiser <: SOUND;
	 		 	 stop=1;
	 		 	 break;
	 		 case right :> newDirection:
	 			 right :> newVelocity;
	 		 	 right <: NO;
	 		 	 right <: currentDirection;
	 		 	 right <: currentVelocity;
	 		 	 currentDirection=newDirection;
	 		     currentVelocity=newVelocity;
	 		     toVisualiser <: SOUND;
	 		 	 stop=1;
	 		 	 break;
	 		 default:
	 			 break;
	 	 }
		 if (stop)
			 break;

	 }

	 return stop;
 }

//PARTICLE...thread to represent a particle - to be replicated noParticle-times
void particle(chanend left, chanend right, chanend toVisualiser, int startPosition, int startDirection, int active,int startVelocity)
{
    for (;;)
    {
        unsigned int position = startPosition; // The current particle position
        int currentDirection = startDirection; // The current direction the particle is moving
        int currentVelocity = startVelocity; // The current particle velocity
        int data, pause = 0, reset = 0;

        // Wait for signal from visualiser
        toVisualiser :> data;
        while (!reset)
        {
            if (pause) // Handling actions in pause state
            {
                select
                {
                case toVisualiser :> data: //performing actions according to the visualiser's message
                    if (data == TERMINATE)
                        return;
                    if (data == RESET)
                        reset = 1;
                    else if (data == UNPAUSE)
                        pause = 0;
                    else if (data == STARTACTIVE)
                    {
                    	active = 1;
                    }
                    else if (data == STARTINACTIVE)
                        active = 0;
                    else if (data == CHANGEVELOCITY)
                    {
                        toVisualiser :> currentVelocity;
                    }
                    else if (data == REQUESTVELOCITY)
                    {
                        toVisualiser <: currentVelocity;
                    }
                    break;

                case left :> currentDirection:
                    left :> currentVelocity;
                    pause = 0;
                    if (active) //collide
                    {
                        left <: NO;
                        left <: currentDirection;
                        left <: currentVelocity;
                    }
                    else //allow move
                    {
                        left <: OK;
                        active = 1;
                    }
                    break;

                case right :> currentDirection:
                    right :> currentVelocity;
                    pause = 0;
                    if (active) //collide
                    {
                        right <: NO;
                        right <: currentDirection;
                        right <: currentVelocity;
                    }
                    else //allow move
                    {
                        right <: OK;
                        active = 1;
                    }
                    break;

                default:
                    break;
                }
            }
            else
            {
                if (active) //handling actions for active particles
                {
                	int newVelocity, newDirection;
                    select
                    {
                    // Handle termination
                    case toVisualiser :> data:
                        if (data == TERMINATE)
                            return;
                        if (data == RESET)
                            reset = 1;
                        else if (data == PAUSE)
                            pause = 1;
                        break;

                    // Handle being collided
                    case left :> data:
                        newDirection = data;
                        left :> data;
                        newVelocity = data;
                        left <: NO;
                        left <: currentDirection;
                        left <: currentVelocity;
                        currentDirection = newDirection;
                        currentVelocity = newVelocity;
                        break;

                    case right :> data:
                        newDirection = data;
                        right :> data;
                        newVelocity = data;
                        right <: NO;
                        right <: currentDirection;
                        right <: currentVelocity;
                        currentDirection = newDirection;
                        currentVelocity = newVelocity;
                        break;

                    default:
                        // Request visualiser state
                        toVisualiser <: REQ;
                        toVisualiser :> data;

                        if (data == OK) //if the state is OK (which means running)
                        {
                            if (currentDirection == 1)
                            {
                            	int newVelocity, newDirection;
                                select //check if right want to communicate first
                                {
                                case right :> data:
                                    newDirection = data;
                                    right :> data;
                                    newVelocity = data;
                                    right <: NO;
                                    right <: currentDirection;
                                    right <: currentVelocity;
                                    currentDirection = newDirection;
                                    currentVelocity = newVelocity;
                                    break;

                                default: //try to move right
                                	data=interactWait(left,right,toVisualiser, TIME/currentVelocity, currentVelocity, currentDirection);
                                	if (!data)
                                	{
										right <: currentDirection;
										right <: currentVelocity;
										right :> data;
										if (data == OK)
										{
											active = 0;
											toVisualiser <: currentDirection;
										}
										else if (data == NO)
										{
											right :> currentDirection;
											right :> currentVelocity;
											toVisualiser <: SOUND;
										}
                                	}
                                    break;
                                }
                            }
                            else if (currentDirection == -1)
                            {
                            	int newVelocity, newDirection;
                                select
                                {//check if right want to communicate first
                                case left :> data:
                                    newDirection = data;
                                    left :> data;
                                    newVelocity = data;
                                    left <: NO;
                                    left <: currentDirection;
                                    left <: currentVelocity;
                                    currentDirection = newDirection;
                                    currentVelocity = newVelocity;
                                    break;

                                default: //try to move right
                                	data=interactWait(left,right,toVisualiser, TIME/currentVelocity, currentVelocity, currentDirection);
                                	if (!data)
                                	{
										left <: currentDirection;
										left <: currentVelocity;
										left :> data;
										if (data == OK)
										{
											active = 0;
											select
											{
												case toVisualiser :> data:
													if (data == TERMINATE)
														return;
													if (data == RESET)
														reset = 1;
													else if (data == PAUSE)
														pause = 1;
													break;
												default:
													break;
											}

											toVisualiser <: currentDirection;


										}
										else if (data == NO)
										{
											left :> currentDirection;
											left :> currentVelocity;
											toVisualiser <: SOUND;
										}
                                	}
                                    break;
                                }
                            }
                        }
                        else if (data == PAUSE)
                            pause = 1;
                        else if (data == RESET)
                            reset = 1;
                        else if (data == TERMINATE)
                            return;
                        break;
                    }
                }
                else if (!active) //handling actions for inactive particles
                {
                    select
                    {
                        case toVisualiser :> data:
                           if (data == TERMINATE)
                               return;
                           if (data == PAUSE)
                               pause = !pause;
                           else if (data == RESET)
                               reset = 1;
                           break;
                        default:
                            break;
                    }
                    select
                    {
                    case left :> currentDirection:
                        left :> currentVelocity;
                        left <: OK;
                        active = 1;
                        break;

                    case right :> currentDirection:
                        right :> currentVelocity;
                        right <: OK;
                        active = 1;
                        break;
                    default:
                        break;
                    }
                }
            }
        }
    }
}

//MAIN PROCESS defining channels, orchestrating and starting the threads
int main()
{
    chan quadrant[4]; //helper channels for LED visualisation
    chan show[noParticles]; //channels to link visualiser with particles
    chan neighbours[noParticles]; //channels to link neighbouring particles
    chan buttonToVisualiser; //channel to link buttons and visualiser

    //MAIN PROCESS HARNESS
    par
    {
        on stdcore[0]: buttonListener(buttons, buttonToVisualiser);
        on stdcore[0]: visualiser(buttonToVisualiser, show, quadrant, speaker);

        par (int k=0;k<4;k++)
        {
            on stdcore[k%4]: showLED(cled[k],quadrant[k]);
        }

        par (int k = 0; k < noParticles; ++k)
        {
            on stdcore[k%4]: particle(neighbours[k], neighbours[(k+1) % noParticles], show[k], k, k%2*2 - 1, (k == 0 || k == 3 || k == 6) ? 1 : 0, (k+1));
        }
    }
    return 0;
}
