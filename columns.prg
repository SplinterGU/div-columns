program columns;

import "mod_gfx";
import "mod_input";
import "mod_misc";
import "mod_sound";
import "mod_debug";

const
    maxgames = 4;

global
    // define our game struct
    // this allows a columns game to be started anywhere on scren
    // any any number of grids
    struct gameinfo[ maxgames ]
        // main grid info
        struct grid[ 6 ]
            int col[ 16 ];
            int newmatch[ 16 ];
            int matched[ 16 ];
            int gmatched[ 16 ];
        end
        struct gridcache[ 6 ]
            int col[ 16 ];
        end
        // struct that stores the grid used for the hints
        // and for the cpu player
        struct hints[ 3 ] // each "swap" variant
            struct cols[ 6 ] // each possible position
                struct grid[ 6 ] // regular grid copy
                    int col[ 16 ];
                end
                int score;
            end
        end
        // player data
        int score = 0;
        int level = 0;
        int jewelcount = 0;
        int chain = 0;
        // general game data
        // next / in play jewels
        int next[ 3 ];
        int play[ 3 ];
        int jewels; // random jewels (4 - 6 usually)
        int gameover = 0;
        // AI data
        int ts; // starget swap
        int tc; // target column
        int matched = 0;
        int checkmatch = 0;
        int smash = 0;
        int newmatch = 0;
        int xpos;
        int ypos;
        int incscore = 0;
        int newscore = 0;
        int nextx;
        int played = 1;
        int playing = 0;
        int colpos[ 6 ];
        // auto play data
        int autoswap = 0;
        int autoright = 0;
        int autoleft = 0;
        int autodown = 0;
        int autoplay = 0;
        int auto = 0;
        int updateboards = 0;
        int speed = 0;
        int playerid = -1;
        int region;
        int ctype;
        int cnumber;
        int magic = 1;
        int magicmatch = 0;
    END

    // levels upgrade at this number of jewels removed - should be a formula
    int levels[ 20 ] = 10, 70, 105, 140, 150, 180, 210, 240, 270, 300, 330, 360, 390, 420, 450, 480, 510, 100000000;

    // key struct for each player
    struct keys[ maxgames ]
        int left;
        int right;
        int up;
        int down;
        int swap;
        int start;
        int auto;
    end = _left, _right, _up, _down, _space, _1, _3,
          _a, _d, _w, _s, _w, _2, _4,
          _left, _right, _up, _down, _space, _1, _3;

    // set attract mode
    int attract = 1;
    int players = 2;
    int timeout = 0;
    int sounds[ 8 ];
    int numbersfpg = 0;

    int joy_plr[1] = -1, -1;
    struct controller[1]
        int left;
        int right;
        int up;
        int down;
        int swap;
        int start;
    end
end

declare process press_start();
declare process demo( num );
declare process game( xpos, ypos, num );
declare function gameoveranim( num );
declare process gameoversprite( num );
declare process wipe( num, double y );
declare process wipes( num, double x, y );
declare function getnext( num );
declare process smash( xpos, ypos, num );
declare process jewel( xpos, ypos, num );
declare process shownext( num );
declare process _next( num, idx );
declare process player( num );
declare process pjewel( num, idx );
declare process titlegems();
declare process gem1( graph, xdir, yoff );
declare process joystick( num );
declare process button( num );
declare process newpoints( num );
declare process scorenum( region, num, double x, y, int scg, pos, sy, chain, slen );
declare function load_sounds();
declare function boot();
declare function fadeoffon();
declare function bestmove( num );
declare function nextscore( num, swap, pos );
declare function setupmatch( num );
declare function fill3();
declare process fill2( map, double x, y, int source, target );
declare process fill( map, double x, y, int source, target );
declare function filljewels();
declare process jeweltest( double x, y );


PROCESS input_handler()
BEGIN
    WHILE( 1 )
        IF ( !joy_query( joy_plr[ 0 ], JOY_QUERY_ATTACHED ) ) joy_plr[ 0 ] = -1; end
        IF ( !joy_query( joy_plr[ 1 ], JOY_QUERY_ATTACHED ) ) joy_plr[ 1 ] = -1; end

        FOR( int plr = 0; plr <= 1; plr++ )
            IF ( joy_plr[ plr ] == -1 )
                FOR ( int i = 0; i < 16; i++ )
                    IF ( i != joy_plr[ plr ^ 1 ] && joy_query( i, JOY_QUERY_ATTACHED ) )
                        joy_plr[ plr ] = i;
                    END
                END
            END

            controller[ plr ].left  = key( keys[ plr ].left );
            controller[ plr ].right = key( keys[ plr ].right );
            controller[ plr ].up    = key( keys[ plr ].up );
            controller[ plr ].down  = key( keys[ plr ].down );
            controller[ plr ].swap  = key( keys[ plr ].swap );
            controller[ plr ].start = key( keys[ plr ].start );

            IF ( joy_plr[ plr ] != -1 )
                controller[ plr ].left   |= joy_query( joy_plr[ plr ], JOY_BUTTON_DPAD_LEFT    ) || joy_query( joy_plr[ plr ], JOY_AXIS_LEFTX ) < -16384;
                controller[ plr ].right  |= joy_query( joy_plr[ plr ], JOY_BUTTON_DPAD_RIGHT   ) || joy_query( joy_plr[ plr ], JOY_AXIS_LEFTX ) > 16383;
                controller[ plr ].up     |= joy_query( joy_plr[ plr ], JOY_BUTTON_DPAD_UP      ) || joy_query( joy_plr[ plr ], JOY_AXIS_LEFTY ) < -16384;
                controller[ plr ].down   |= joy_query( joy_plr[ plr ], JOY_BUTTON_DPAD_DOWN    ) || joy_query( joy_plr[ plr ], JOY_AXIS_LEFTY ) > 16383;

                controller[ plr ].swap   |= joy_query( joy_plr[ plr ], JOY_BUTTON_B            ) || joy_query( joy_plr[ plr ], JOY_BUTTON_A            ) ||
                                            joy_query( joy_plr[ plr ], JOY_BUTTON_X            ) || joy_query( joy_plr[ plr ], JOY_BUTTON_Y            );

                controller[ plr ].start  |= joy_query( joy_plr[ plr ], JOY_BUTTON_START        );
            END
        END
        FRAME;
    END
end


process main()
begin
    screen.scale_resolution = 06400448;
    screen.scale_resolution_aspectratio = SRA_PRESERVE;
    // setup our video mode
    set_mode( 320, 224 );
    set_fps( 30, 0 );

    // load our graphics
    fpg_load( "columns.fpg" );
    numbersfpg = fpg_load( "numbers.fpg" );
    fnt_load( "columns.fnt" );

    input_handler();

    // load sounds
    load_sounds();

    // show boot screen
    boot();

    for ( x = 1; x < 20; x++ )
        levels[ x ] = levels[ 0 ] + ( x + 1 ) * 40;
    end
    levels[ 19 ] = max_int;
    // next piece position for dual screen
    gameinfo[ 0 ].nextx = 120;
    gameinfo[ 1 ].nextx = 184;
    // single player
    gameinfo[ 2 ].nextx = 88;
    //main operating loop
    loop
        size = 100;
        timer[ 0 ] = 0;
        // columns title
        graph = 206;
        x = 160;
        y = 50;
        // men intro with bag
        background.file = 0;
        background.graph = 205 - ( players == 1 );
        // bag of gems process
        if ( players == 2 )
            titlegems();
        end
        // show this screen for 10 seconds
        press_start();
        while ( !controller[ 0 ].swap && !controller[ 1 ].swap && timer[ 0 ] < 1000 )
            frame;
        end
        if ( !controller[ 0 ].swap || !controller[ 1 ].swap )
            sound_play( sounds[ 2 ] );
        end
        signal( type press_start, s_kill );
        // reset timer
        timer[ 0 ] = 0;
        // kill the gems spawning from the bag
        signal( type titlegems, s_kill_tree );
        frame;
        // hide "columns" title
        graph = 0;

        fadeoffon();

        // show the arcade (two player) games grid
        switch ( players )
            case 1:
                // show the single player grid
                background.file = 0;
                background.graph = 217;
                // spawn the single player process
                game( 112, 8, 2 );
                joystick( 2 );
            end
            case 2:
                background.file = 0;
                background.graph = 203;
                gameinfo[ 0 ].gameover = 0;
                gameinfo[ 1 ].gameover = 0;
                game( 16, 8, 0 );
                game( 208, 8, 1 );
                /*
                gameinfo[3].nextx=326;
                game(336,8,3);

                for(x=4;x<9;x++)
                    gameinfo[x].nextx=(x-4)*127;
                    game(16+((x-4)*127),248,x);
                end
                */
            end
        end
        frame;
        timeout = timer[ 0 ] + 1000;
        // show this grid for 10 seconds, or until escape press
        // or continuously if not in attract mode
        repeat
            // only check every second
            frame( 2400 );
            if ( gameinfo[ 0 ].playing == 1 ||
                 gameinfo[ 1 ].playing == 1 ||
                 gameinfo[ 2 ].playing == 1 )
                timeout = timer[ 0 ] + 1000;
            end
        until ( timer[ 0 ] > timeout );

        scroll_stop( 1 );
        scroll_stop( 2 );
        scroll_stop( 3 );
        fadeoffon();
        // reset time
        timer[ 0 ] = 0;
        //kill the game(s) and all subprocesses
        signal( type game, s_kill_tree );
        signal( type joystick, s_kill_tree );
        write_delete( all_text );
        frame;
        players = 1 - players + 2;
    end // end main loop
end

process press_start()
private
    int flip = 0;
begin
    graph = 414;
    x = 160;
    y = 180;
    loop
        flip++;
        flip = flip % 10;
        if ( flip < 5 )
            graph = 0;
        else
            graph = 414;
        end
        frame( 300 );
    end
end


process demo( num )
private
    int flip = 0;
begin
    graph = 415;
    ctype = c_scroll;
    region = num + 1;
    cnumber = father.cnumber;
    x = 48;
    y = 180;
    loop
        flip++;
        flip = flip % 10;
        if ( flip < 5 )
            graph = 0;
        else
            graph = 415;
        end
        frame( 300 );
    end
end


process game( xpos, ypos, num )
// start game engine in a scroll region starting x,y
private
    int falls = 0;
    int gaps = 0;
    int gx = 0;
    int gy = 0;

    int flip = 0;
    int s = 0;
begin
    // background grid
    gameinfo[ num ].gameover = 0;
    x = 3 * 16 + 1; //xpos+3*16+1;
    y = 7 * 16 + 8;
    //flip=num*16;
    // set number of random jewels in this game
    gameinfo[ num ].jewels = 6; //4;//;//6;//+rand(0,2);
    // set the game zpos ypos
    gameinfo[ num ].xpos = 0; //xpos;
    gameinfo[ num ].ypos = 0; //ypos;
    // setup a region for this grid (makes the sprite hiding easy)
    // xpos now only used to setup the scroll / region
    region_define( num + 1, xpos, ypos, 96, 208 );
    scroll_start( num + 1, file, 0, 301, num + 1, 15 );

    // put the folowing in an array!
    if ( num == 0 )
        write_var( 1, 120, 114, 3, gameinfo[ num ].score );
        write_var( 1, 120, 154, 3, gameinfo[ num ].level );
        write_var( 1, 120, 186, 3, gameinfo[ num ].jewelcount );
//        region_define( num + 1 + maxgames, 110, 64, 60, 46 ); // score region
        region_define( num + 1 + maxgames, 120, 64, 40, 16 ); // score region
    end
    if ( num == 1 )
        write_var( 1, 198, 138, 5, gameinfo[ num ].score );
        write_var( 1, 198, 178, 5, gameinfo[ num ].level );
        write_var( 1, 198, 210, 5, gameinfo[ num ].jewelcount );
//        region_define( num + 1 + maxgames, 160, 88, 60, 46 ); // score region
        region_define( num + 1 + maxgames, 160, 88, 40, 16 ); // score region
    end
    if ( num == 2 )
        write_var( 1, 102, 138, 5, gameinfo[ num ].score );
        write_var( 1, 102, 178, 5, gameinfo[ num ].level );
        write_var( 1, 102, 210, 5, gameinfo[ num ].jewelcount );
//        region_define( num + 1 + maxgames, 64, 88, 60, 46 ); // score region
        region_define( num + 1 + maxgames, 64, 88, 40, 16 ); // score region
    end

    region = num + 1;
    cnumber = 1 << ( num + 1 );
    ctype = c_scroll;
    gameinfo[ num ].region = region;
    gameinfo[ num ].cnumber = cnumber;
    gameinfo[ num ].ctype = ctype;
    gameinfo[ num ].speed = 200;
    gameinfo[ num ].next[ 0 ] = 0;
    gameinfo[ num ].next[ 1 ] = 0;
    gameinfo[ num ].next[ 2 ] = 0;
    // reset the grid to zero
    // and spawn jewels
    for ( gx = 0; gx < 6; gx++ )
        for ( gy = 15; gy >= 0; gy-- )
            gameinfo[ num ].grid[ gx ].col[ gy ] = 0;
            //if(gy>10)
            //    gameinfo[num].grid[gx].col[gy]=1;
            //else
            jewel( gx, gy, num );
            //end
        end
    end
    loop
        // gameinfo[num].autoplay=1;
        //  gameinfo[num].jewels=6;//rand(5,6);
        //  myplayer=player(num);
        //gameinfo[num].playing=0;
        //   frame;
        while ( gameinfo[ num ].playing == 0 )
            flip++;
            flip = flip % 32;
            if ( flip < 16 )
                graph = 0;
            else
                graph = 401 + ( num % 2 );
            end
//            if ( key( keys[ num ].auto ) )
//                gameinfo[ num ].autoplay = 1;
//            end
            if ( controller[ num ].start || controller[ num ].swap || controller[ num ].up /*|| key( keys[ num ].auto ) */)
                gameinfo[ num ].autoplay = 0;
                gameinfo[ num ].score = 0;
                gameinfo[ num ].level = 0;
                gameinfo[ num ].jewelcount = 0;
                gameinfo[ num ].jewels = 6;
                gameinfo[ num ].played = 0;
                gameinfo[ num ].magic = 0;
                signal( gameinfo[ num ].playerid, s_kill_tree );
                //frame;
                gameinfo[ num ].playerid = player( num );
                gameinfo[ num ].playing = 1;
            end
//            if ( key( keys[ num ].auto ) )
//                gameinfo[ num ].autoplay = 1;
//                gameinfo[ num ].jewels = 6;
//            end
            frame;
            graph = 0;
        end
        // game started
        gameinfo[ num ].gameover = 0;
        // mini loop until piece have been placed
        repeat
            frame;
        until ( gameinfo[ num ].played == 1 );
        // once piece has been placed, check for "wins"
        // and check for drops
        gameinfo[ num ].chain = 1;
        repeat // while wins
            // check for matches
            gameinfo[ num ].checkmatch = 1;
            frame;
            gameinfo[ num ].magicmatch = 0;
            if ( gameinfo[ num ].matched > 0 )
                gameinfo[ num ].smash = 28;
                frame;
                gameinfo[ num ].newscore = ( 30 * ( gameinfo[ num ].level + 1 ) * gameinfo[ num ].chain ) * gameinfo[ num ].incscore;
                gameinfo[ num ].incscore = 0;
                newpoints( num );
                frame;
                repeat
                    frame; //(200);
                    if ( gameinfo[ num ].smash == 8 )
                        // && gameinfo[num].autoplay==0);
                        sound_play( sounds[ 0 ] );
                    end
                    if ( gameinfo[ num ].smash < 7 )
                        frame;
                    end
                    gameinfo[ num ].smash--;
                until ( gameinfo[ num ].smash == 0 );
                frame;
            end
            gameinfo[ num ].checkmatch = 0;
            repeat // while falls
                falls = 0;
                gaps = 0;
                for ( gy = 14; gy >= 0; gy-- )
                    for ( gx = 0; gx < 6; gx++ )
                        gameinfo[ num ].grid[ gx ].matched[ gy ] = 0;
                        if ( gameinfo[ num ].grid[ gx ].col[ gy ] == 0 )
                            gaps = 1;
                            if ( gy > 0 )
                                if ( gameinfo[ num ].grid[ gx ].col[ gy -1 ] > 0 )
                                    gameinfo[ num ].grid[ gx ].col[ gy ] = gameinfo[ num ].grid[ gx ].col[ gy -1 ];
                                    gameinfo[ num ].grid[ gx ].col[ gy -1 ] = 0;
                                    falls = 1;
                                end
                            end
                        end
                    end
                end
                frame;
            until ( falls == 0 )
            gameinfo[ num ].checkmatch = 1;
            gameinfo[ num ].matched = 0;
            // check magic jewel glitch
            from xpos = 0 to 5;
                from ypos = 3 to 15;
                    if ( gameinfo[ num ].grid[ xpos ].col[ ypos ] == 10 )
                        //            debug;
                        gameinfo[ num ].magicmatch = gameinfo[ num ].grid[ xpos ].col[ ypos + 1 ];
                        gameinfo[ num ].grid[ xpos ].col[ ypos ] = -10;
                        gameinfo[ num ].matched = 1;
                    end
                end
            end
            frame;
            gameinfo[ num ].chain++;
        until ( gameinfo[ num ].matched == 0 );
        gameinfo[ num ].checkmatch = 0;
        if ( gameinfo[ num ].jewelcount > levels[ gameinfo[ num ].level ] && gameinfo[ num ].level < 20 )
            gameinfo[ num ].level++;
            if ( gameinfo[ num ].level < 3 )
                gameinfo[ num ].jewels = gameinfo[ num ].level + 4;
            end
            sound_play( sounds[ 4 ] );
            if ( gameinfo[ num ].level % 5 == 1 )
                gameinfo[ num ].magic = 1;
            end
        end
        if ( attract == 1 )
            if ( gaps == 0 )
                for ( gy = 12; gy >= 0; gy-- )
                    for ( gx = 0; gx < 6; gx++ )
                        gameinfo[ num ].grid[ gx ].col[ gy ] = 0;
                    end
                end
            end
        end
        frame;
        gameinfo[ num ].played = 0;
        if ( gameinfo[ num ].gameover == 1 )
            gameoveranim( num );
        end
    end
end


function gameoveranim( num )
private
    int gy = 0;
    int gx = 0;
begin
    gameoversprite( num );
    for ( gy = 15; gy >= 0; gy-- )
        for ( gx = 0; gx < 6; gx++ )
            gameinfo[ num ].grid[ gx ].col[ gy ] = 0;
        end
        //if(gameinfo[num].autoplay==0);
        sound_play( sounds[ 1 ] );
        //end
        wipe( num, gy );
        frame( gameinfo[ num ].speed );
    end
    gy = 0;
    while ( gy < 3 )
        gameinfo[ num ].next[ gy ] = 0;
        gy++;
    end
    //stop_sound(s);
    gy = 100;
    while ( gy > 0 )
        gy--;
        frame;
    end
    signal( gameinfo[ num ].playerid, s_kill_tree );
    frame;
    gameinfo[ num ].playing = 0;
    //gameinfo[num].gameover=0;
end


process gameoversprite( num )
begin
    graph = 410;
    x = gameinfo[ num ].xpos + 3 * 16;
    y = gameinfo[ num ].ypos + 8 + 16 * 20;
    region = gameinfo[ num ].region;
    cnumber = gameinfo[ num ].cnumber;
    ctype = gameinfo[ num ].ctype;
    gameinfo[ num ].autoplay = 0;
    while ( gameinfo[ num ].gameover == 1 )
        if ( y > 92 )
            y -= 8;
        end
        graph = rand( 410, 413 );
        frame;
    end
end


process wipe( num, double y )
begin
    for ( x = 0; x < 6; x++ )
        wipes( num, x, y );
    end
end


process wipes( num, double x, y )
begin
    graph = 60;
    region = gameinfo[ num ].region;
    cnumber = gameinfo[ num ].cnumber;
    ctype = gameinfo[ num ].ctype;
    x = gameinfo[ num ].xpos + 8 + x * 16;
    y = gameinfo[ num ].ypos + 8 + ( y -2 ) * 16;
    while ( graph < 67 );
        frame( gameinfo[ num ].speed );
        graph++;
    end
end


function getnext( num )
begin
    while ( x < 3 )
        if ( gameinfo[ num ].magic == 1 )
            gameinfo[ num ].next[ x ] = 10;
        else
            gameinfo[ num ].next[ x ] = rand( 1, gameinfo[ num ].jewels );
        end
        x++;
    end
    gameinfo[ num ].magic = 0;
    return;
end


process smash( xpos, ypos, num )
private
    int pos = 0;
    int flip = 0;
    int jewelid;
    int jewelm;
    int xg = 0;
    int xc = 0;
    int yc = 0;
    int xcc = 0;
    int ycc = 0;

    int maidx;
    int matchpos;
    int matchswap;
begin
    graph = 0;
    region = num + 1;
    cnumber = 1 << ( num + 1 );
    ctype = c_scroll;
    x = xpos * 16 + gameinfo[ num ].xpos + 8;
    y = ypos * 16 + gameinfo[ num ].ypos + 8 -32;
    loop
        if ( gameinfo[ num ].smash > 0 && gameinfo[ num ].grid[ xpos ].col[ ypos ] < 0 ||
            ( gameinfo[ num ].magicmatch > 0 && gameinfo[ num ].magicmatch == gameinfo[ num ].grid[ xpos ].col[ ypos ] ))
            gameinfo[ num ].grid[ xpos ].matched[ ypos ] = 0;
            jewelid = abs( gameinfo[ num ].grid[ xpos ].col[ ypos ] );
            graph = 1 + 10 * ( jewelid -1 );
            gameinfo[ num ].grid[ xpos ].col[ ypos ] = 0;
            //gameinfo[num].incscore+=(10*(gameinfo[num].level+1))*gameinfo[num].chain;
            frame;
            while ( gameinfo[ num ].smash > 8 )
                if ( jewelid == 10 )
                    graph = 70 + ( timer[ 0 ] / 5 ) % 6; //+offs;
                end
                size = 0;
                if ( gameinfo[ num ].smash % 4 < 2 )
                    size = 100;
                end
                frame;
            end
            gameinfo[ num ].grid[ xpos ].col[ ypos ] = 0;
            repeat
                graph = 67 - gameinfo[ num ].smash;
                frame;
            until ( gameinfo[ num ].smash == 0 );
            gameinfo[ num ].grid[ xpos ].matched[ ypos ] = 0;
            gameinfo[ num ].jewelcount++;
        end
        if ( gameinfo[ num ].level < 2 && gameinfo[ num ].played == 0 && gameinfo[ num ].grid[ xpos ].col[ ypos ] > 0 &&
            gameinfo[ num ].grid[ xpos ].matched[ ypos ] > 0 )
            if ( timer[ 0 ] % 20 < 10 );
                graph = 10; // highlight box round gem
            end
        end
        frame;
        graph = 0;
    end
end


process jewel( xpos, ypos, num )
private
    int jewelid = 0;
    int px = 0;
    int py = 0;
    int shimmer = 0;
    int above = 0;

    int counter = 0;
begin
    region = num + 1;
    ctype = c_scroll;
    cnumber = 1 << ( num + 1 );
    x = xpos * 16 + gameinfo[ num ].xpos + 8;
    y = ypos * 16 + gameinfo[ num ].ypos + 8 -32;

    smash( xpos, ypos, num );

    loop
        // check if jewel has changed
        if ( abs( gameinfo[ num ].grid[ xpos ].col[ ypos ] ) != jewelid )
            counter = 5;
            jewelid = abs( gameinfo[ num ].grid[ xpos ].col[ ypos ] );
            graph = 0;
            if ( jewelid > 0 )
                graph = 1 + ( jewelid -1 ) * 10;
            end
        end
        if ( counter > 0 )
            counter--;
        end
        if ( jewelid == 10 )
            graph = 70 + ( timer[ 0 ] / 5 ) % 6;
        end
        if ( jewelid > 0 && jewelid < 10 && counter == 0 )
            if ( shimmer == 0 )
                if ( above == 0 )
                    if ( ypos > 0 )
                        if ( gameinfo[ num ].grid[ xpos ].col[ ypos -1 ] != 0 )
                            shimmer = 7;
                        end
                    end
                end
            end
            if ( shimmer > 0 )
                graph = 1 + ( jewelid -1 ) * 10 + ( 9 - shimmer );
                shimmer--;
                if ( shimmer == 0 )
                    graph = 1 + ( jewelid -1 ) * 10;
                end
            end
        end
        if ( ypos > 0 )
            above = abs( gameinfo[ num ].grid[ xpos ].col[ ypos -1 ] );
        end
        if ( gameinfo[ num ].checkmatch == 1 && jewelid > 0 )
            if ( ypos > 0 )
                if ( gameinfo[ num ].magicmatch == jewelid )
                    gameinfo[ num ].grid[ xpos ].col[ ypos ] = - jewelid;
                    gameinfo[ num ].matched = 1;
                end
                if ( abs( gameinfo[ num ].grid[ xpos ].col[ ypos -1 ] ) == jewelid &&
                    abs( gameinfo[ num ].grid[ xpos ].col[ ypos + 1 ] ) == jewelid )
                    gameinfo[ num ].grid[ xpos ].col[ ypos -1 ] = - jewelid;
                    gameinfo[ num ].grid[ xpos ].col[ ypos ] = - jewelid;
                    gameinfo[ num ].grid[ xpos ].col[ ypos + 1 ] = - jewelid;
                    gameinfo[ num ].matched = 1;
                    gameinfo[ num ].incscore++;
                end
            end
            if ( xpos > 0 && xpos < 5 )
                if ( abs( gameinfo[ num ].grid[ xpos -1 ].col[ ypos ] ) == jewelid &&
                    abs( gameinfo[ num ].grid[ xpos + 1 ].col[ ypos ] ) == jewelid )
                    gameinfo[ num ].grid[ xpos -1 ].col[ ypos ] = - jewelid;
                    gameinfo[ num ].grid[ xpos + 1 ].col[ ypos ] = - jewelid;
                    gameinfo[ num ].grid[ xpos ].col[ ypos ] = - jewelid;
                    gameinfo[ num ].matched = 1;
                    gameinfo[ num ].incscore++;
                end
                if ( ypos > 0 )
                    if ( abs( gameinfo[ num ].grid[ xpos -1 ].col[ ypos -1 ] ) == jewelid &&
                        abs( gameinfo[ num ].grid[ xpos + 1 ].col[ ypos + 1 ] ) == jewelid )
                        gameinfo[ num ].grid[ xpos -1 ].col[ ypos -1 ] = - jewelid;
                        gameinfo[ num ].grid[ xpos + 1 ].col[ ypos + 1 ] = - jewelid;
                        gameinfo[ num ].grid[ xpos ].col[ ypos ] = - jewelid;
                        gameinfo[ num ].matched = 1;
                        gameinfo[ num ].incscore++;
                    end
                    if ( abs( gameinfo[ num ].grid[ xpos -1 ].col[ ypos + 1 ] ) == jewelid &&
                        abs( gameinfo[ num ].grid[ xpos + 1 ].col[ ypos -1 ] ) == jewelid )
                        gameinfo[ num ].grid[ xpos -1 ].col[ ypos + 1 ] = - jewelid;
                        gameinfo[ num ].grid[ xpos + 1 ].col[ ypos -1 ] = - jewelid;
                        gameinfo[ num ].grid[ xpos ].col[ ypos ] = - jewelid;
                        gameinfo[ num ].matched = 1;
                        gameinfo[ num ].incscore++;
                    end
                end
            end
        end
        frame;
    end
end


process shownext( num )
begin
    for ( x = 0; x < 3; x++ )
        _next( num, x );
    end
    loop
        frame;
    end
end


process _next( num, idx )
private
    int jewelid = -1;
    int target = 0;
begin
    x = gameinfo[ num ].nextx + 8;
    y = 16 + idx * 16 + 240 * ( num > 3 );
    graph = 0;
    loop
        if ( father.father.y < 24 && gameinfo[ num ].played == 0 && gameinfo[ num ].play[ idx ] > 0 )
            target = gameinfo[ num ].play[ idx ];
        else
            target = gameinfo[ num ].next[ idx ];
        end
        if ( target != jewelid )
            jewelid = target;
            graph = 1 + ( target -1 ) * 10;
        end
        if ( jewelid == 10 )
            graph = 70 + ( timer[ 0 ] / 5 ) % 6;
        end
        frame;
    end
end


process player( num )
private
    int dropinter = 100;
    int dropnext = 0;
    int xpos = 2;
    int ypos = 1;
    int d = 0;
    int gameover = 0;
    int tp = 0;
    int donenext = 0;
    int cpos = 0;
    int repeatdelay = 5;
    int repeatcount = 0;
    int oldkey = 0;
begin
    gameinfo[ 0 ].played = 0;
    region = num + 1;
    cnumber = 1 << ( num + 1 );
    ctype = c_scroll;
    //show player jewels
    x = -100;
    pjewel( num, 0 );
    pjewel( num, 1 );
    pjewel( num, 2 );
    getnext( num );

    if ( gameinfo[ num ].autoplay == 1 )
        demo( num );
    end

    // display the "next" jewels
    shownext( num );

    loop
        while ( gameinfo[ num ].gameover == 1 )
            frame;
        end
        // populate the "next" grid
        for ( tp = 0; tp < 3; tp++ )
            gameinfo[ num ].play[ tp ] = gameinfo[ num ].next[ tp ];
        end
        //    gameinfo[num].roll=0;
        donenext = 0;
        getnext( num );
        setupmatch( num );
        gameinfo[ num ].updateboards = 1;
        bestmove( num );
        cpos = 0;
        frame;
        // copy the next into the current
        // we need 3 copies.
        // current
        // next
        // in play
        //
        // since the next changes as the current comes into view
        // out half/tile position
        d = 0;
        // exact grid positions
        xpos = 2;
        ypos = 1;
        // player box outline
        graph = 300;
        y = -32;
        x = 40; //gameinfo[num].xpos+8+16*xpos;
        // reset the gameinfo to say the piece is "in play"
        gameinfo[ num ].played = 0;
        frame;
        // main loop, repeated until gameover
        repeat
//            if ( key( _c ))
//                gameinfo[ num ].magic = 1;
//            end
            if ( oldkey != 0 )
                if (
                    ( oldkey == _LEFT  && !controller[ num ].left    ) ||
                    ( oldkey == _RIGHT && !controller[ num ].right   ) ||
                    ( oldkey == _UP    && !controller[ num ].up      ) ||
                    ( oldkey == _S     && !controller[ num ].swap    )
                   )
                    oldkey = 0;
                end

                if ( repeatcount < repeatdelay + 1 )
                    repeatcount++;
                end
            end
            // auto play
            if ( gameinfo[ num ].autoplay == 1 )
                //if(key(keys[num].start || key(keys[num].swap)))
                //    gameinfo[num].gameover=1;
                //    break;
                // end
                gameinfo[ num ].autoswap = 0;
                gameinfo[ num ].autoleft = 0;
                gameinfo[ num ].autoright = 0;
                gameinfo[ num ].autodown = 0;
                //frame;
                if ( gameinfo[ num ].auto == 1 && gameinfo[ num ].played == 0 )
                    if ( gameinfo[ num ].ts != cpos )
                        gameinfo[ num ].autoswap = 1;
                    end
                    if ( gameinfo[ num ].tc > xpos )
                        gameinfo[ num ].autoright = 1;
                    end
                    if ( gameinfo[ num ].tc < xpos )
                        gameinfo[ num ].autoleft = 1;
                    end
                    if ( gameinfo[ num ].played == 0 && gameinfo[ num ].autoswap == 0 && gameinfo[ num ].autoleft == 0 && gameinfo[ num ].autoright == 0 )
                        gameinfo[ num ].autodown = 1;
                    end
                end
            end
            if ( controller[ num ].swap || controller[ num ].up || gameinfo[ num ].autoswap == 1 )
                if (( oldkey != _S && oldkey != _UP ) || repeatcount > repeatdelay )
                    if ( controller[ num ].swap )
                        if ( oldkey != _S )
                            repeatcount = 0;
                            oldkey = _S;
                        end
                    end
                    if ( controller[ num ].up )
                        if ( oldkey != _UP )
                            repeatcount = 0;
                            oldkey = _UP;
                        end
                    end
                    sound_play( sounds[ 6 ] );
                    cpos++;
                    if ( cpos == 3 )
                        cpos = 0;
                    end
                    tp = gameinfo[ num ].play[ 2 ];
                    gameinfo[ num ].play[ 2 ] = gameinfo[ num ].play[ 1 ];
                    gameinfo[ num ].play[ 1 ] = gameinfo[ num ].play[ 0 ];
                    gameinfo[ num ].play[ 0 ] = tp;
                end
            end
            if ( gameinfo[ num ].autoleft == 1 || ( controller[ num ].left && xpos > 0 ))
                if ( oldkey != _LEFT || repeatcount > repeatdelay )
                    if ( oldkey != _LEFT )
                        repeatcount = 0;
                        oldkey = _LEFT;
                    end
                    if ( gameinfo[ num ].grid[ xpos -1 ].col[ ypos ] == 0 &&
                        gameinfo[ num ].grid[ xpos -1 ].col[ ypos -1 * ( ypos > 1 ) ] == 0 )
                        x -= 16;
                        xpos--;
                    end
                end
            end
            if ( gameinfo[ num ].autoright == 1 || ( controller[ num ].right && xpos < 5 ))
                if ( oldkey != _RIGHT || repeatcount > repeatdelay )
                    if ( oldkey != _RIGHT )
                        repeatcount = 0;
                        oldkey = _RIGHT;
                    end
                    if ( gameinfo[ num ].grid[ xpos + 1 ].col[ ypos ] == 0 &&
                        gameinfo[ num ].grid[ xpos + 1 ].col[ ypos -1 * ( ypos > 1 ) ] == 0 )
                        x += 16;
                        xpos++;
                    end
                end
            end
            if ( controller[ num ].down || timer[ 1 ] > dropnext || gameinfo[ num ].autodown == 1 )
                dropnext = timer[ 1 ] + dropinter - ( gameinfo[ num ].level * 9 );
                if ( controller[ num ].down || gameinfo[ num ].autodown == 1 )
                    gameinfo[ num ].score++;
                end
                // check if block below is free
                d = 1 - d;
                y += 8;
                //if(y==32 && donenext==0)
                //    getnext(num);
                //    donenext=1;
                // end
                if ( d == 0 )
                    ypos++;
                    // end
                    //if(d==0)
                    if ( ypos == 15 || gameinfo[ num ].grid[ xpos ].col[ ypos ] != 0 )
                        y = y -8;
                        //xpos=(x-8-(gameinfo[num].xpos))/16;
                        //ypos=(y-(y%16))/16+2;
                        ypos--;
                        //if(x>0)
                        // populate play grid
                        if ( ypos > 1 && xpos >= 0 )
                            if ( ypos > 3 )
                                gameinfo[ num ].grid[ xpos ].col[ ypos -2 ] = gameinfo[ num ].play[ 0 ];
                            end
                            if ( ypos > 2 )
                                gameinfo[ num ].grid[ xpos ].col[ ypos -1 ] = gameinfo[ num ].play[ 1 ];
                            end
                            if ( ypos > 1 )
                                gameinfo[ num ].grid[ xpos ].col[ ypos ] = gameinfo[ num ].play[ 2 ];
                                if ( gameinfo[ num ].play[ 2 ] == 10 )
                                    gameinfo[ num ].magicmatch = gameinfo[ num ].grid[ xpos ].col[ ypos + 1 ];
                                end
                            end
                            //end
                        else
                            gameinfo[ num ].gameover = 1;
                        end
                        //if(gameinfo[num].autoplay==0);
                        sound_play( sounds[ 3 ] );
                        // end
                        gameinfo[ num ].played = 1;
                        frame;
                        x = -100;
                        y = -100;
                        //frame(200);
                    end
                end
            end
            //if(gameinfo[num].autoplay==1)
            //    frame(5);
            //else
            frame;
            //end
            //if(!gameinfo[num].autodown && !gameinfo[num].auto)
            //    frame;
            //end
        until ( gameinfo[ num ].played == 1 );
        gameinfo[ num ].autoswap = 0;
        gameinfo[ num ].autoleft = 0;
        gameinfo[ num ].autoright = 0;
        gameinfo[ num ].autodown = 0;
        for ( tp = 0; tp < 3; tp++ )
            gameinfo[ num ].play[ tp ] = 0;
        end
        // hide the player jewels and wait until main loop
        // has done its checks to resume play
        x = -100;
        repeat
            frame;
        until ( gameinfo[ num ].played == 0 )
    end
    // never reached?
    debug;
end


process pjewel( num, idx )
private
    int idy;
    // show the jewels the player has
begin
    x = -100;
    priority = father.priority -1;
    region = num + 1;
    cnumber = 1 << ( num + 1 );
    ctype = c_scroll;
    idy = idx * 16;
    // repeat whilst not gameover
    loop
        // if(gameinfo[num].autoplay==1)
        //flags=4;
        //  end
        if ( gameinfo[ num ].gameover == 0 )
            graph = ( gameinfo[ num ].play[ idx ] -1 ) * 10 + 1;
            if ( gameinfo[ num ].play[ idx ] == 10 )
                graph = 70 + ( timer[ 0 ] / 5 ) % 6; //+offs;
            end
            // get coords from player
            x = father.x;
            y = father.y - 16 + idy;
        else
            graph = 0;
        end
        frame;
    end
end

// gems out of the bag on title

process titlegems()
begin
    //graph=219;
    for ( y = -1; y < 2; y++ )
        gem1( 219, -2, y );
        gem1( 220, -1, y );
        gem1( 221, 0, y );
        gem1( 220, 1, y );
        gem1( 219, 2, y );
    end
    loop
        frame;
    end
end


process gem1( graph, xdir, yoff )
private
    int ydir;
    int count;
begin
    // repeat forever
    loop
        count = 0;
        x = 160;
        y = 116;
        if ( abs( xdir ) == 1 );
            y += 2;
        end
        if ( abs( xdir ) == 2 );
            y += 7;
        end
        ydir = -6;
        size = 100;
        while ( count < 40 ) //y<200+6*(abs(xdir)))//!region_out(id,0));
            graph++;
            if ( graph == 222 )
                graph = 219;
            end
            count++;
            if ( ydir < 0 )
                x = x + xdir;
            end
            y += ydir;
            if ( ydir < 5 )
                ydir++;
            end
            if ( y > 120 && size > 0 )
                size -= 8;
            end
            if ( count == 15 )
                y += 4 * ( abs( yoff ));
                x += 4 * ( yoff );
            end
            frame;
        end
    end
end

// on screen joystick and buttons

process joystick( num )
begin
    if ( num == 2 )
        x = 240;
        y = 200;
    else
        ctype = c_scroll;
        cnumber = father.cnumber;
        region = father.region;
        x = 32;
        y = 200;
    end
    button( num );
    loop
        graph = 210;
        if ( controller[ 0 ].left || gameinfo[ num ].autoleft == 1 )
            graph = 211;
        end
        if ( controller[ num ].right || gameinfo[ num ].autoright == 1 )
            graph = 212;
        end
        if ( controller[ num ].down || gameinfo[ num ].autodown == 1 )
            graph = 213;
        end
        /*
    if(gameinfo[num].autoplay==1)
        graph+=100;
    end
  */
        frame;
    end
end


process button( num )
begin
    if ( num == 2 )
        x = 300;
        y = 190;
    else
        ctype = c_scroll;
        cnumber = father.cnumber;
        region = father.region;
        x = 72;
        y = 180;
    end
    loop
        graph = 214;
        if ( controller[ num ].swap || gameinfo[ num ].autoswap == 1 )
            graph = 215;
        end
        /*
    if(gameinfo[num].autoplay==1)
        graph+=100;
    end
    */
        frame;
    end
end


process newpoints( num )
private
    int xoff;
    int yoff;
    int sy = 0;
    int score = 0;
    int mscore = 0;
    int scg = 0;
    int pos = 0;
    int d = 0;
    string snum;
    int slen;
    int chain = 0;
begin
    region = num + 1 + maxgames;
    if ( num == 0 )
        xoff = 116;
        yoff = 64;
    end
    if ( num == 1 )
        xoff = 160 - 16;
        yoff = 88;
    end
    if ( num == 2 )
        xoff = 64 - 16;
        yoff = 88;
    end

    x = xoff + 48 + 8;
    y = yoff - 16;
    sy = y;

    graph = 10;
    file = numbersfpg;

    //loop
    while ( gameinfo[ num ].newscore == 0 )
        frame;
    end
    chain = gameinfo[ num ].chain;
    score = gameinfo[ num ].newscore;
    mscore = score;
    gameinfo[ num ].newscore = 0;

    snum = itoa( score );
    slen = strlen( snum );

    while ( mscore > 0 )
        scg = mscore % 10;
        mscore -= scg;
        mscore /= 10;
        if ( scg == 0 )
            scg = 10;
        end
        x -= 8;
        pos++;
        scorenum( region, num, x, y, scg, pos, sy, chain, slen );
    end
    frame( 3500 );
    gameinfo[ num ].score += score;
    score = 0;
end


process scorenum( region, num, double x, y, int scg, pos, sy, chain, slen )
private
    int d = 0;
begin
    if ( num == 0 )
        x += ( slen - 3 ) * 8;
    end
    file = numbersfpg;
    graph = scg;
    if ( scg == 0 )
        graph = 10;
    end
    graph += 10 * ( chain -1 );
    frame( pos * 200 );
    repeat
        y += 4;
        if ( y - sy == 24 )
            d = 0;
            repeat
                frame;
                d++;
            until ( d == 21 );
        end
        //graph=scg;
        flags = 0;
        if ( y - sy > 32 )
            y += 4;
            flags = 4;
        end
        frame;
    until ( y - sy > 64 )
end

// END OF GAME PROCESES
/////////////////////
/////////////////////
// Helper Functions

function load_sounds()
// load sounds
// 0 - smash
// 1 - game over noise (repeated)
// 2 - select
// 3 - drop
// 4 - level up?
// 5 - magic jewel?
// 6 - swap
// 7 - ????
begin
    for ( x = 0; x < 8; x++ )
        sounds[ x ] = sound_load( "wav/fx" + itoa( x ) + ".wav" ); //(x==1));
    end
end


function boot()
begin
    timer[ 0 ] = 0;

    // colour bars
    background.file = 0;
    background.graph = 209;

    while ( !controller[0].swap && !controller[1].swap && timer[0] < 200 )
        frame;
    end

    background.file = 0;
    background.graph = 0;

    filljewels();
    // show the sega logo
    set_fps( 60, 0 );
    fill3();
    set_fps( 30, 0 );
    graph = 216;
    x = 161;
    y = 121;
    size = 100;
    timer[ 0 ] = 0;
    while ( timer[ 0 ] < 200 )
        frame;
    end
    //shrink logo to zero
    while ( size > 0 )
        size -= 10;
        frame;
    end
end

// Fades the screen off, then on

function fadeoffon()
begin
    fade_off(500);
    while ( fade_info.fading )
        frame;
    end
    fade_on(500);
end

// select the best move to use
// for the cpu player

function bestmove( num )
private
    int bests = 0;
    int bestc = 0;
    int score;
    int best = 0;
    int bestpos;
    int possible[ 6 ];
begin
    // prevent game moving until we have got a move
    gameinfo[ num ].auto = 0;
    for ( x = 0; x < 3; x++ )
        for ( y = 0; y < 6; y++ )
            score = gameinfo[ num ].hints[ x ].cols[ y ].score; //+gameinfo[num].colpos[y];
            possible[ y ] = 0;
            if ( score > best )
                bests = x;
                bestc = y;
                best = score;
            end
        end
    end
    if ( best == 0 )
        bests = rand( 0, 2 );
        bestc = rand( 0, 5 );
        bestpos = 0;
        for ( x = 0; x < 6; x++ )
            if ( gameinfo[ num ].colpos[ x ] >= bestpos )
                bestpos = gameinfo[ num ].colpos[ x ];
                bestc = x; //gameinfo[num].colpos[x];
            end
        end
    end
    // store best move data for cpu to target
    gameinfo[ num ].ts = bests;
    gameinfo[ num ].tc = bestc;
    gameinfo[ num ].auto = 1;
end


function nextscore( num, swap, pos )
private
    struct testgrid[ 6 ]
        int cols[ 16 ];
        int matched[ 16 ];
    end
    int xpos = 0;
    int ypos = 0;
    int spos = 0;
    int cpos = 0;
    int colpos[ 6 ];
    int piece[ 3 ];
    int tp = 0;
    int oldscore;
    int newscore;
    int jewelid;
    int drops = 0;
    int multi = 0;
begin
    for ( x = 0; x < 3; x++ )
        piece[ x ] = gameinfo[ num ].next[ x ];
    end
    // get drop position for each piece
    for ( x = 0; x < 6; x++ )
        //gameinfo[num].colpos[x]=0;
        colpos[ x ] = 0;
        for ( y = 14; y > 0; y-- )
            if ( gameinfo[ num ].gridcache[ x ].col[ y ] == 0 );
                colpos[ x ] = y;
                //      gameinfo[num].colpos[x]=y;
                break;
            end
        end
    end
    //debug;
    for ( spos = 0; spos < 3; spos++ )
        for ( cpos = 0; cpos < 6; cpos++ )
            // copy grid
            for ( xpos = 0; xpos < 6; xpos++ )
                for ( ypos = 0; ypos < 15; ypos++ )
                    testgrid[ xpos ].cols[ ypos ] = gameinfo[ num ].gridcache[ xpos ].col[ ypos ];
                end
            end
            // place our piece
            for ( x = 0; x < 3; x++ )
                if ( colpos[ cpos ] - x >= 0 )
                    testgrid[ cpos ].cols[ colpos[ cpos ] - x ] = piece[ 2 - x ];
                end
            end
            //debug;
            multi = 1;
            repeat
                oldscore = gameinfo[ num ].hints[ swap ].cols[ pos ].score;
                // check matches
                for ( xpos = 0; xpos < 6; xpos++ )
                    for ( ypos = 0; ypos < 15; ypos++ )
                        // reset match this board
                        testgrid[ xpos ].matched[ ypos ] = 0;
                        jewelid = testgrid[ xpos ].cols[ ypos ];
                        if ( jewelid > 0 )
                            if ( ypos > 0 )
                                if ( testgrid[ xpos ].cols[ ypos -1 ] == jewelid &&
                                    testgrid[ xpos ].cols[ ypos + 1 ] == jewelid )
                                    testgrid[ xpos ].matched[ ypos -1 ] = jewelid;
                                    testgrid[ xpos ].matched[ ypos + 1 ] = jewelid;
                                    testgrid[ xpos ].matched[ ypos ] = jewelid;
                                    //debug;
                                    gameinfo[ num ].hints[ swap ].cols[ pos ].score += multi;
                                end
                            end
                            if ( xpos > 0 && xpos < 5 )
                                if ( testgrid[ xpos -1 ].cols[ ypos ] == jewelid &&
                                    testgrid[ xpos + 1 ].cols[ ypos ] == jewelid )
                                    testgrid[ xpos -1 ].matched[ ypos ] = jewelid;
                                    testgrid[ xpos + 1 ].matched[ ypos ] = jewelid;
                                    testgrid[ xpos ].matched[ ypos ] = jewelid;
                                    //debug;
                                    gameinfo[ num ].hints[ swap ].cols[ pos ].score += multi;
                                end
                                if ( ypos > 0 )
                                    if (
                                        testgrid[ xpos -1 ].cols[ ypos -1 ] == jewelid &&
                                        testgrid[ xpos + 1 ].cols[ ypos + 1 ] == jewelid )
                                        testgrid[ xpos -1 ].matched[ ypos -1 ] = jewelid;
                                        testgrid[ xpos + 1 ].matched[ ypos + 1 ] = jewelid;
                                        testgrid[ xpos ].matched[ ypos ] = jewelid;
                                        //debug;
                                        gameinfo[ num ].hints[ swap ].cols[ pos ].score += multi;
                                    end
                                    if ( testgrid[ xpos -1 ].cols[ ypos + 1 ] == jewelid &&
                                        testgrid[ xpos + 1 ].cols[ ypos -1 ] == jewelid )
                                        testgrid[ xpos -1 ].matched[ ypos + 1 ] = jewelid;
                                        testgrid[ xpos + 1 ].matched[ ypos -1 ] = jewelid;
                                        testgrid[ xpos ].matched[ ypos ] = jewelid;
                                        //debug;
                                        gameinfo[ num ].hints[ swap ].cols[ pos ].score += multi;
                                    end
                                end
                            end
                        end
                    end
                end
                // make gaps
                for ( xpos = 0; xpos < 6; xpos++ )
                    for ( ypos = 0; ypos < 15; ypos++ )
                        if ( testgrid[ xpos ].matched[ ypos ] > 0 )
                            testgrid[ xpos ].cols[ ypos ] = 0;
                            testgrid[ xpos ].matched[ ypos ] = 0;
                        end
                    end
                end
                // drops
                repeat
                    drops = 0;
                    for ( xpos = 0; xpos < 6; xpos++ )
                        for ( ypos = 1; ypos < 15; ypos++ )
                            if ( testgrid[ xpos ].cols[ ypos ] == 0 )
                                if ( testgrid[ xpos ].cols[ ypos -1 ] > 0 )
                                    testgrid[ xpos ].cols[ ypos ] = testgrid[ xpos ].cols[ ypos -1 ];
                                    testgrid[ xpos ].cols[ ypos -1 ] = 0;
                                    drops = 1;
                                end
                            end
                        end
                    end
                    multi++;
                until ( drops == 0 );
                newscore = gameinfo[ num ].hints[ swap ].cols[ pos ].score - oldscore;
            until ( newscore == 0 )
        end
        // rotate pieces for next loop
        tp = piece[ 2 ];
        piece[ 2 ] = piece[ 1 ];
        piece[ 1 ] = piece[ 0 ];
        piece[ 0 ] = tp;
    end
end


function setupmatch( num )
private
    int col;
    int tp = 0;
    int xpos = 0;
    int ypos = 0;
    int jewelid = 0;
    int matchpos = 0;
    int matchswap = 0;
    int newscore = 0;
    int oldscore = 0;
    int piece[ 4 ];
    int drops = 0;
    int first = 0;
    int multi = 0;
    int colpos[ 6 ]; // to store our drop targets
begin
    for ( x = 0; x < 6; x++ )
        for ( y = 0; y < 15; y++ )
            gameinfo[ num ].grid[ x ].matched[ y ] = 0;
        end
    end
    for ( col = 0; col < 6; col++ ) // each possible position
        for ( x = 0; x < 3; x++ )
            piece[ x ] = gameinfo[ num ].play[ x ];
        end
        for ( graph = 0; graph < 3; graph++ ) // each swap
            gameinfo[ num ].hints[ graph ].cols[ col ].score = 0;
            matchswap = graph;
            matchpos = col;
            for ( x = 0; x < 6; x++ ) // copy main grid
                gameinfo[ num ].colpos[ x ] = 0;
                for ( y = 0; y < 15; y++ )
                    gameinfo[ num ].hints[ graph ].cols[ col ].grid[ x ].col[ y ] =
                    gameinfo[ num ].grid[ x ].col[ y ];
                    if ( gameinfo[ num ].grid[ x ].col[ y ] == 0 );
                        gameinfo[ num ].colpos[ x ] = y;
                        colpos[ x ] = y;
                    end
                end
            end
            // copy piece to grid in position / swapped
            // rotate pieces (doesnt matter about the order, as long as they match
            // button presses.
            // we use 4 slots instead of 3 to use as a temp value.
            for ( x = 0; x < 3; x++ )
                if ( colpos[ col ] - x >= 0 )
                    gameinfo[ num ].hints[ graph ].cols[ col ].grid[ col ].col[ colpos[ col ] - x ] = piece[ 2 - x ];
                end
            end
            // set score for this grid
            first = 0;
            multi = 10;
            repeat
                oldscore = gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].score;
                for ( xpos = 0; xpos < 6; xpos++ )
                    if ( colpos[ x ] > 1 )
                        for ( ypos = 0; ypos < 15; ypos++ )
                            // reset match this board
                            gameinfo[ num ].grid[ xpos ].gmatched[ ypos ] = 0;
                            jewelid = gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos ].col[ ypos ];
                            if ( jewelid > 0 )
                                if ( ypos > 0 )
                                    if ( gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos ].col[ ypos -1 ] == jewelid &&
                                        gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos ].col[ ypos + 1 ] == jewelid )
                                        if ( first == 0 )
                                            gameinfo[ num ].grid[ xpos ].matched[ ypos ] = jewelid;
                                            gameinfo[ num ].grid[ xpos ].matched[ ypos -1 ] = jewelid;
                                            gameinfo[ num ].grid[ xpos ].matched[ ypos + 1 ] = jewelid;
                                        end
                                        if ( gameinfo[ num ].autoplay == 1 )
                                            gameinfo[ num ].grid[ xpos ].gmatched[ ypos ] = jewelid;
                                            gameinfo[ num ].grid[ xpos ].gmatched[ ypos -1 ] = jewelid;
                                            gameinfo[ num ].grid[ xpos ].gmatched[ ypos + 1 ] = jewelid;
                                            gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].score += multi;
                                        end
                                    end
                                end
                                if ( xpos > 0 && xpos < 5 )
                                    if ( gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos -1 ].col[ ypos ] == jewelid &&
                                        gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos + 1 ].col[ ypos ] == jewelid )
                                        if ( first == 0 )
                                            gameinfo[ num ].grid[ xpos ].matched[ ypos ] = jewelid;
                                            gameinfo[ num ].grid[ xpos -1 ].matched[ ypos ] = jewelid;
                                            gameinfo[ num ].grid[ xpos + 1 ].matched[ ypos ] = jewelid;
                                        end
                                        if ( gameinfo[ num ].autoplay == 1 )
                                            gameinfo[ num ].grid[ xpos ].gmatched[ ypos ] = jewelid;
                                            gameinfo[ num ].grid[ xpos -1 ].gmatched[ ypos ] = jewelid;
                                            gameinfo[ num ].grid[ xpos + 1 ].gmatched[ ypos ] = jewelid;
                                            gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].score += multi;
                                        end
                                    end
                                    if ( ypos > 0 )
                                        if ( gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos -1 ].col[ ypos -1 ] == jewelid &&
                                            gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos + 1 ].col[ ypos + 1 ] == jewelid )
                                            if ( first == 0 )
                                                gameinfo[ num ].grid[ xpos ].matched[ ypos ] = jewelid;
                                                gameinfo[ num ].grid[ xpos -1 ].matched[ ypos -1 ] = jewelid;
                                                gameinfo[ num ].grid[ xpos + 1 ].matched[ ypos + 1 ] = jewelid;
                                            end
                                            if ( gameinfo[ num ].autoplay == 1 )
                                                gameinfo[ num ].grid[ xpos ].gmatched[ ypos ] = jewelid;
                                                gameinfo[ num ].grid[ xpos -1 ].gmatched[ ypos -1 ] = jewelid;
                                                gameinfo[ num ].grid[ xpos + 1 ].gmatched[ ypos + 1 ] = jewelid;
                                                gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].score += multi;
                                            end
                                        end
                                        if ( gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos -1 ].col[ ypos + 1 ] == jewelid &&
                                            gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos + 1 ].col[ ypos -1 ] == jewelid )
                                            if ( first == 0 )
                                                gameinfo[ num ].grid[ xpos ].matched[ ypos ] = jewelid;
                                                gameinfo[ num ].grid[ xpos -1 ].matched[ ypos + 1 ] = jewelid;
                                                gameinfo[ num ].grid[ xpos + 1 ].matched[ ypos -1 ] = jewelid;
                                            end
                                            if ( gameinfo[ num ].autoplay == 1 )
                                                gameinfo[ num ].grid[ xpos ].gmatched[ ypos ] = jewelid;
                                                gameinfo[ num ].grid[ xpos -1 ].gmatched[ ypos + 1 ] = jewelid;
                                                gameinfo[ num ].grid[ xpos + 1 ].gmatched[ ypos -1 ] = jewelid;
                                                gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].score += multi;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                first++;
                multi++;
                newscore = gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].score - oldscore;
                // check for drops
                if ( newscore > 0 && gameinfo[ num ].autoplay == 1 )
                    //gameinfo[num].hints[matchswap].cols[matchpos].score>0)
                    drops = 0;
                    // make holes in the board
                    for ( xpos = 0; xpos < 6; xpos++ )
                        for ( ypos = 14; ypos > 0; ypos-- )
                            if ( gameinfo[ num ].grid[ xpos ].gmatched[ ypos ] > 0 )
                                gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos ].col[ ypos ] = 0;
                                gameinfo[ num ].grid[ xpos ].gmatched[ ypos ] = 0;
                            end
                        end
                    end
                    repeat
                        drops = 0;
                        for ( xpos = 0; xpos < 6; xpos++ )
                            for ( ypos = 1; ypos < 15; ypos++ )
                                if ( gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos ].col[ ypos ] == 0 &&
                                    gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos ].col[ ypos -1 ] > 0 )
                                    gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos ].col[ ypos ] =
                                    gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos ].col[ ypos -1 ];
                                    gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos ].col[ ypos -1 ] = 0;
                                    drops = 1;
                                end
                            end
                        end
                    until ( drops == 0 );
                    //    debug;
                end
            until ( newscore == 0 )
            // all drops done
            // run each variant of next, in each position and get some more score for this grid
            for ( xpos = 0; xpos < 6; xpos++ );
                for ( ypos = 0; ypos < 15; ypos++ )
                    gameinfo[ num ].gridcache[ xpos ].col[ ypos ] = gameinfo[ num ].hints[ matchswap ].cols[ matchpos ].grid[ xpos ].col[ ypos ];
                end
            end
            //gameinfo[num].hints[matchswap].cols[matchpos].score+=
            nextscore( num, matchswap, matchpos );
            // swap the piece for the next move
            tp = piece[ 2 ];
            piece[ 2 ] = piece[ 1 ];
            piece[ 1 ] = piece[ 0 ];
            piece[ 0 ] = tp;
        end
    end
end


function fill3()
private
    int map;
begin
    while ( controller[0].swap || controller[1].swap )
        frame;
    end
    map = 223;
    graph = map;
    x = 160;
    y = 120;
    fill2( map, 2, 2, 1, 120 );
    repeat
        frame;
    until ( !get_id( type fill ) || controller[0].swap || controller[1].swap );
    signal( type fill, s_kill );
end


process fill2( map, double x, y, int source, target )
begin
    fill( map, x, y, source, target );
end


process fill( map, double x, y, int source, target )
private
    int pixel;
    int xpos;
    int ypos;
    int xpos_final;
    int ypos_final;
begin
    xpos_final = father.x;
    ypos_final = father.y;
    pixel = map_get_pixel( file, map, x, y );
    if ( pixel != target )
        map_put_pixel( file, map, x, y, target );
        frame;
        FROM xpos = -1 TO 1;
            FROM ypos = -1 to 1;
                if ( !( x + xpos == xpos_final && y + ypos == ypos_final ) && x + xpos >= 0 && y + ypos >= 0 && !( xpos == 0 && ypos == 0 ))
                    pixel = map_get_pixel( file, map, x + xpos, y + ypos );
                    if ( pixel == source )
                        fill( map, x + xpos, y + ypos, source, target );
                    end
                end
            end
        end
    end
end


function filljewels()
begin
    for ( x = 8; x < 320; x += 16 )
        for ( y = 8; y < 240; y += 16 )
            jeweltest( x, y );
        end
    end
    frame;
    while ( get_id( type jeweltest ));
        frame;
    end
end


process jeweltest( double x, y );
private
    int c;
begin
    while ( c < 24 );
        graph = 1 + 10 * rand( 0, 5 );
        c++;
        frame;
    end
    frame( 1200 );
end
