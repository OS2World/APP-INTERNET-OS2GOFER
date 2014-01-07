/****************************************************************************/
/* Simple OS/2 2.0 Gopher Client                                            */
/* Requires "Visual Rexx (VREXX)" from IBM or ftp-os2.nmsu.edu              */
/* Arguments (optional)                                                     */
/*    server port  (for initial menu)                                       */
/* This version handles Gopher data types                                   */
/*    0 (a document) Display with EPM                                       */
/*    1 (a folder)   Display as list box                                    */
/*    7 (keyword)    Enter keywords and make query                          */
/*    8 (telnet)     VT100 telnet using TCP/IP for OS/2                     */
/*    T (TN3270)     TN3270 telnet using TN3270                             */
/****************************************************************************/
parse arg server port                  /* get arguments in lower case       */

"@ECHO OFF"
                                       /* The default server is umn         */
if arg(1,'o') then server="gopher.micro.umn.edu"

   do while (queued()>0)               /* The OS/2 REXX queue is global to  */
      parse pull line                  /* the session.  There could be stuff*/
   end                                 /* from a previous command. Flush it.*/

/****************************************************************************/
/* VREXX is an IBM employee written piece of OS/2 software.  It pipes       */
/* requests from this character mode REXX session to a PM process which     */
/* generates windows and dialogs.  This code initializes it.                */
/****************************************************************************/
call RxFuncAdd 'VInit', 'VREXX', 'VINIT'
initcode = VInit()
if initcode = 'ERROR' then signal CLEANUP

signal on failure name CLEANUP
signal on halt name CLEANUP
signal on syntax name CLEANUP

/****************************************************************************/
/* Call the rodent.c code to generate a TCP/IP transaction to the first     */
/* server to get an initial menu.  The server gets a null request and       */
/* presents its normal entry menu.  The results are put on the stack.       */
/****************************************************************************/
"rodent" server port "|rxqueue"

/****************************************************************************/
/* An internal procedure (see below) now displays the menu and requests     */
/* a selection.  When the user cancels this menu, we are done.              */
/****************************************************************************/
call showlist

   call VExit                          /* normal exit                       */
exit

CLEANUP:
   call VExit                          /* abnormal exit                     */
   say "Termdinated by error" condition('C')
exit


/****************************************************************************/
/* showlist - an internal procedure to display a gohper "menu"              */
/* This routine is called with the reply to a gopher query on the           */
/* stack.  It removes the stack lines, classifies them by type, and         */
/* displays the items it understands.  The user makes a selection or        */
/* hits CANCEL.  CANCEL returns from this procedure.                        */
/****************************************************************************/
showlist: procedure
debug=1

path=value("TEMP",,"OS2ENVIRONMENT")   /* set up a data file name           */
if length(path)>0 then path=path||"\"
path=path||"GOPHER.DAT"

                                       /* Read Gopher menu from stack       */
i=1
   do while (queued()>0)
      /**********************************************************************/
      /* A gopher menu is a set of lines                                    */
      /* each line has four tab delimited fields                            */
      /*    title   query   server   port                                   */
      /* For debugging, the line is first pulled as a string and then       */
      /* is parsed into fields.                                             */
      /**********************************************************************/
      parse pull line
      if length(line)<3 then iterate
      parse var line type.i 2 title.i '09'x query.i '09'x server.i '09'x port.i rest
      if verify(type.i,"0178T")\=0 & debug then say "ignoring" line
      else
        do
        /********************************************************************/
        /* Ideally, the items would be iconized.  VREXX does not have       */
        /* containers, so we create a little icon where <> is a directory   */
        /* and [] is a document.                                            */
        /********************************************************************/
        if type.i="0" then title.i="[]" title.i
        if type.i="1" then title.i="<>" title.i
        if type.i="7" then title.i="KW" title.i
        if type.i="8" then title.i="{}" title.i
        if type.i="T" then title.i="{}" title.i
        i=i+1
        end
   end

/****************************************************************************/
/* Generally every gopher menu contains other menus or documents.  It is    */
/* possible that the menu would contain only unsupported item types.        */
/****************************************************************************/
i=i-1
if i=0 then return

/****************************************************************************/
/* Now setup for a VREXX display.  See VREXX.INF for details                */
/****************************************************************************/
title.0=i                              /* number of items                   */
title.vstring = list.1                 /* Default is item 1                 */

if i>10 then height=10                 /* How high is scroll box            */
else height=i

   do forever                          /* Actually, do till CANCEL          */
   /*************************************************************************/
   /* Display a list box dialog with menu items and OK/CANCEL               */
   /*************************************************************************/
   call VDialogPos 50, 50              /* Put in middle of screen           */
   call VListBox 'Select an item', title, 50, height, 3

   /*************************************************************************/
   /* Now the user may have made a selection, or may have hit CANCEL        */
   /*************************************************************************/
   if result="CANCEL" then return;     /* Not with a bang but a wimper      */

     do  i = 1 to title.0              /* VREXX returns string, not number  */
        if title.vstring=title.i then  /* have to search to find selection  */
           do
           if type.i ="1" then         /* Its another menu                  */
              do                       /* Put it on the queue               */
              /**************************************************************/
              /* Get another menu and call this routine recursively         */
              /**************************************************************/
              "rodent" server.i port.i '"'||query.i||'" |RXQUEUE'
              call showlist            /* Call myself again                 */
              leave
              end

           if type.i = "0" then        /* Its a document                    */
              do
              /**************************************************************/
              /* Read document, write it to disk, call EPM editor           */
              /**************************************************************/
              "rodent" server.i port.i '"'||query.i||'" >' path
              "EPM" path               /* Edit it with favorite editor      */
              leave
              end

           if type.i = "7" then        /* Keyword search                    */
              do
              /**************************************************************/
              /* Free text keyword search                                   */
              /**************************************************************/
              prompt.0 = 1
              prompt.1 = "Enter keyword search"
              button=VInputBox("Gopher Keyword Search",prompt,50,3)
              if button="CANCEL" then leave
              "rodent" server.i port.i '"'||query.i||'09'x||prompt.vstring||'" |RXQUEUE'
              call showlist
              leave
              end

           if type.i = "8" then        /* Its a Telnet                      */
              do
              /**************************************************************/
              /* Telnet to host                                             */
              /**************************************************************/
              say query.i
              if port.i=0 then port.i=""
              "vt100 " server.i port.i
              leave
              end

           if type.i = "T" then        /* Its a Telnet                      */
              do
              /**************************************************************/
              /* Tn3270 to host                                             */
              /**************************************************************/
              say query.i
              if port.i=0 then port.i=""
              "tn3270" server.i port.i
              leave
              end
           end
     end
   end
