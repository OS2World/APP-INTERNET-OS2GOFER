/****************************************************************************/
/* Rodent.c - Gopher Transaction Generator                                  */
/* For OS/2 2.0 with C SET/2 Compiler (32 bit) and TCP/IP for OS/2 1.2.1    */
/* To compile, requires hacked \TCPIP\INCLUDE adapted to 32 bit compiler    */
/* Could be easily changed to use MS C 6.00 with vanilla TCP code for       */
/* a 16 bit version, but the author resists going back to MSC6.             */
/*                                                                          */
/* arguments                                                                */
/*    server - domain name of gopher server                                 */
/*    port   - port number                                                  */
/*    query  - null or search string (second tab delimited field in menu)   */
/*                                                                          */
/* The output of a gopher query is a standard ASCII text file ending        */
/* in a line consisting of just a single "." charcter.  However, to be      */
/* sure the server then terminates the TCP connection.  This code           */
/* reads until the TCP session ends and writes the results to the           */
/* standard output.  Generally the results are piped to a program or        */
/* redirected to a temporary file.                                          */
/****************************************************************************/

#define DEFAULT_HOST "gopher.micro.umn.edu"
#define DEFAULT_PORT 70

#include <stdio.h>
#include <string.h>
                                       /* These may be hacked for 32 bit    */
#include <types.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <netlib.h>
#include <netdb.h>
#include <sys/ioctl.h>
#include <nerrno.h>
#include <process.h>

                                       /* Swap bits of short integer        */
#define MAYBESWAP(w)   (((((w)&0xff)<<8)&0xff00) | ((((w)&0xff00)>>8)&0xff) )
                                       /* Note: htons, ntohs, and bswap     */
                                       /* are unresolved by TCPIPDLL        */
                                       /* so we use a macro instead         */

void main(int argc,char * argv[])
{
struct sockaddr_in name;
struct hostent * host;
int i,rc,fd;
unsigned short port;
char buf[4096];
void * _Seg16 h;


     fd=socket(AF_INET,SOCK_STREAM,0); /* Create a socket                   */
     if (fd<=0)
        {perror("Can't create socket");
        return;}

     if (argc>1) host = gethostbyname(argv[1]);
     else        host = gethostbyname(DEFAULT_HOST);
     if (!host)
        {perror("Host %s not found");
        return;}

     if (argc>2) port =atoi(argv[2]);
     else        port = DEFAULT_PORT;

     name.sin_family = AF_INET;
     name.sin_port = MAYBESWAP(port);

     /***********************************************************************/
     /* The following code takes the output of gethostbyaddr, a             */
     /* _Seg16 pointer to a _Seg16 pointer to a long integer, and           */
     /* finds the four byte IP address. CSET2+TCP1.2.1 hack.                */
     /***********************************************************************/
     h=*(void * _Seg16 * _Seg16) host->h_addr_list;
     name.sin_addr.s_addr = *(long * _Seg16) h;

     rc=connect(fd,(struct sockaddr *) &name, sizeof(name));
     if (rc<0)
        {
        perror ("Connection failed");
        soclose(fd);
        return;
        }

     if (argc>3) strcpy(buf,argv[3]);  /* Specific query text               */
     else        buf[0]=0;             /* null query, get default menu      */
     strcat(buf,"\r\n");               /* append CR LF                      */
     rc=send(fd,buf,strlen(buf),0);    /* Send any query                    */

     for (;;)
        {
        rc=recv(fd,buf,4095,0);        /* read the reply                    */
        if (rc<=0) break;              /* until "end of file"               */
        buf[rc]=0;                     /* mark end of string                */
        printf("%s",buf);              /* write to standard output          */
        }

     soclose(fd);
}
