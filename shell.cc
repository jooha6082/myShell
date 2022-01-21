#include <cstdio>
#include <unistd.h>
#include <stdlib.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <sys/wait.h>

#include "shell.hh"

int yyparse(void);

void Shell::prompt() {
  if (isatty(0)) {
    char * prompt = getenv("PROMPT");
    char * onerror = getenv("ON_ERROR");

    if (prompt != NULL) {
      printf("%s", prompt);
    } else if (onerror != NULL) {
      printf("%s", onerror);
    } else {
      printf("myshell>");
    }
  }
  fflush(stdout);
}

extern "C" void ctrlc(int sig) {
  fprintf(stderr, "\nsig: %d  Ouch!\n", sig);
  Shell::prompt();
}

extern "C" void killzombie(int sig) {
  pid_t pid = wait3(0, 0, NULL);
  while (waitpid(-1, NULL, WNOHANG) > 0);
}

int main() {
  struct sigaction sa;
  sa.sa_handler = ctrlc;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = SA_RESTART;
  if (sigaction(SIGINT, &sa, NULL)) {
    perror("sigaction");
    exit(2);
  }

  struct sigaction signalAction;
  signalAction.sa_handler = killzombie;
  sigemptyset(&signalAction.sa_mask);
  signalAction.sa_flags = SA_RESTART;
  int error = sigaction(SIGCHLD, &signalAction, NULL);
  if (error) {
    perror("sigaction");
    exit(-1);
  }

  Shell::prompt();
  yyparse();
}

Command Shell::_currentCommand;
