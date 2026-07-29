#include <stdio.h>
#include <pthread.h>
#define THREADS 8
#define BOOKINGS_PER_THREAD 1000
static int seats=5000;
static pthread_mutex_t mutex=PTHREAD_MUTEX_INITIALIZER;
static void* worker(void* arg){
    (void)arg;
    for(int i=0;i<BOOKINGS_PER_THREAD;i++){
        pthread_mutex_lock(&mutex);
        if(seats>0){seats--;}
        pthread_mutex_unlock(&mutex);
    }
    return NULL;
}
void run_reservation_test(void){
    pthread_t t[THREADS];
    for(int i=0;i<THREADS;i++){
        pthread_create(&t[i],NULL,worker,NULL);
    }
    for(int i=0;i<THREADS;i++){
        pthread_join(t[i],NULL);
    }
    printf("Remaining seats: %d",seats);
}
