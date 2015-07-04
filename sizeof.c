#include <sys/types.h>
#include <sys/socket.h>
#include <sys/select.h>
       #include <netinet/in.h>
       #include <arpa/inet.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/epoll.h>
#include <errno.h>

int main(int argc,char** argv){
    printf("Sizeof in_addr: %d\n",sizeof(struct in_addr));
    printf("Sizeof short: %d\n",sizeof(short));
    printf("Sizeof unsigned short: %d\n",sizeof(unsigned short));
    printf("Sizeof long: %d\n",sizeof( long));
    printf("Sizeof unsigned int: %d\n",sizeof(unsigned int));
    printf("Sizeof u_int: %d\n",sizeof(u_int));
    printf("Sizeof fd_set: %d\n",sizeof(fd_set));
    printf("==============================================\n");
    printf("O_NONBLOCK: %d\n",O_NONBLOCK);
    printf("F_GETFL: %d\n",F_GETFL);
    printf("F_SETFL: %d\n",F_SETFL);
    printf("EPOLLIN: %d\n",EPOLLIN);
    printf("EPOLLET: %d\n",EPOLLET);
    printf("EPOLL_CTL_ADD: %d\n",EPOLL_CTL_ADD);
    printf("EPOLLONESHOT: %d\n",EPOLLONESHOT);
    printf("EAGAIN: %d\n",EAGAIN);
}
