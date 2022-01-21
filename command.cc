/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 * DO NOT PUT THIS PROJECT IN A PUBLIC REPOSITORY LIKE GIT. IF YOU WANT 
 * TO MAKE IT PUBLICALLY AVAILABLE YOU NEED TO REMOVE ANY SKELETON CODE 
 * AND REWRITE YOUR PROJECT SO IT IMPLEMENTS FUNCTIONALITY DIFFERENT THAN
 * WHAT IS SPECIFIED IN THE HANDOUT. WE OFTEN REUSE PART OF THE PROJECTS FROM  
 * SEMESTER TO SEMESTER AND PUTTING YOUR CODE IN A PUBLIC REPOSITORY
 * MAY FACILITATE ACADEMIC DISHONESTY.
 */

#include <cstdio>
#include <cstdlib>

#include <iostream>

#include "command.hh"
#include "shell.hh"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <cstring>

extern char ** environ;

Command::Command() {
    // Initialize a new vector of Simple Commands
    _simpleCommands = std::vector<SimpleCommand *>();

    _outFile = NULL;
    _inFile = NULL;
    _errFile = NULL;
    _background = false;
    _append = false;
    _count = 0;
}

void Command::insertSimpleCommand( SimpleCommand * simpleCommand ) {
    // add the simple command to the vector
    _simpleCommands.push_back(simpleCommand);
}

void Command::clear() {
    // deallocate all the simple commands in the command vector
    for (auto simpleCommand : _simpleCommands) {
        delete simpleCommand;
    }

    // remove all references to the simple commands we've deallocated
    // (basically just sets the size to 0)
    _simpleCommands.clear();

    if ( _outFile ) {
        delete _outFile;
    }
    _outFile = NULL;

    if ( _inFile ) {
        delete _inFile;
    }
    _inFile = NULL;

    if ( _errFile ) {
        delete _errFile;
    }
    _errFile = NULL;

    _background = false;

    _append = false;

    _count = 0;
}

void Command::print() {
    printf("\n\n");
    printf("              COMMAND TABLE                \n");
    printf("\n");
    printf("  #   Simple Commands\n");
    printf("  --- ----------------------------------------------------------\n");

    int i = 0;
    // iterate over the simple commands and print them nicely
    for ( auto & simpleCommand : _simpleCommands ) {
        printf("  %-3d ", i++ );
        simpleCommand->print();
    }

    printf( "\n\n" );
    printf( "  Output       Input        Error        Background\n" );
    printf( "  ------------ ------------ ------------ ------------\n" );
    printf( "  %-12s %-12s %-12s %-12s\n",
            _outFile?_outFile->c_str():"default",
            _inFile?_inFile->c_str():"default",
            _errFile?_errFile->c_str():"default",
            _background?"YES":"NO");
    printf( "\n\n" );
}

void Command::execute() {
    // Don't do anything if there are no simple commands
    if ( _simpleCommands.size() == 0 ) {
        if (isatty(0)) {
          Shell::prompt();
        }
        return;
    }

    if (!strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "exit")) {
      printf("Good bye!!\n");
      exit(1);
    }

    if (!strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "setenv")) {
      int set = setenv(_simpleCommands[0]->_arguments[1]->c_str(), _simpleCommands[0]->_arguments[2]->c_str(), 1);
      if (set != 0) {
        perror("setenv");
      }
      clear();
      Shell::prompt();
      return;
    }

    if (!strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "unsetenv")) {
      int unset = setenv(_simpleCommands[0]->_arguments[1]->c_str(), _simpleCommands[0]->_arguments[2]->c_str(), 1);
      if (unset != 0) {
        perror("unsetenv");
      }
      clear();
      Shell::prompt();
      return;
    }

    if (!strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "cd")) {
      int cd;
      //printf("string: %s\n", _simpleCommands[0]->_arguments[1]->c_str());
      if (_simpleCommands[0]->_arguments.size() == 1) {
        cd = chdir(getenv("HOME"));
      } else if (!strcmp(_simpleCommands[0]->_arguments[1]->c_str(), "${HOME}"))  {
        cd = chdir(getenv("HOME"));
      } else {
        cd = chdir(_simpleCommands[0]->_arguments[1]->c_str());
        if (cd != 0) {
          fprintf(stderr, "cd: can't cd to %s\n", _simpleCommands[0]->_arguments[1]->c_str());
        }
      }
      clear();
      Shell::prompt();
      return;
    }


    // Print contents of Command data structure
    if (isatty(0)){
      print();
    }

    // Add execution here
    // For every simple command fork a new process
    // Setup i/o redirection
    // and call exec
    int defaultin = dup( 0 );
    int defaultout = dup( 1 );
    int defaulterr = dup( 2 );
    int infd;
    int outfd;
    int errfd;

    if (_count > 1) {
      printf("Ambiguous output redirect.\n");
      clear();
      if (isatty(0)) {
        Shell::prompt();
      }
      return;
    }

    if (_inFile ) {
      infd = open(_inFile->c_str(), O_RDONLY);

    } else {
      infd = dup(defaultin);
    }

    if (_errFile) {
      if (_append) {
        errfd = open(_errFile->c_str(), O_CREAT | O_WRONLY | O_APPEND, 0664);
      } else {
        errfd = open(_errFile->c_str(), O_CREAT | O_WRONLY | O_TRUNC, 0664);
      }
    } else {
      errfd = dup(defaulterr);
    }
    dup2(errfd, 2);
    close(errfd);

    int ret;
    for (unsigned int i = 0; i < _simpleCommands.size(); i++) {
      dup2(infd, 0);
      close(infd);

      if (i == _simpleCommands.size() - 1) {

        if (_outFile) {
          if (_append) {
            outfd = open(_outFile->c_str(), O_CREAT | O_WRONLY | O_APPEND, 0664);
          } else {
            outfd = open(_outFile->c_str(), O_CREAT | O_WRONLY | O_TRUNC, 0664);
          }

        } else {
          outfd = dup(defaultout);
        }

      } else {

        int fdpipe[2];
        pipe(fdpipe);
        outfd = fdpipe[1];
        infd = fdpipe[0];
      }

      dup2(outfd, 1);
      close(outfd);

      ret = fork();
      if (ret == 0) {

        if (!strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "printenv")) {
          char **p = environ;
          while (*p != NULL) {
            printf("%s\n", *p);
            p++;
          }
          exit(0);
        }

        const char * typed = _simpleCommands[i]->_arguments[0]->c_str();
        char ** argument = new char*[_simpleCommands[i]->_arguments.size() + 1];

        for (unsigned int j = 0; j < _simpleCommands[i]->_arguments.size(); j++) {
          argument[j] = (char *)_simpleCommands[i]->_arguments[j]->c_str();
        }

        argument[_simpleCommands[i]->_arguments.size()] = NULL;
        execvp(typed, argument);
        perror("execvp");
        exit(1);
      } else if (ret < 0) {
        perror("fork");
        return;
      }

    }


    dup2(defaultin, 0);
    dup2(defaultout, 1);
    dup2(defaulterr, 2);
    close(defaultin);
    close(defaultout);
    close(defaulterr);

    if (!_background) {
      waitpid(ret, NULL, 0);
    }
    // Clear to prepare for next command
    clear();

    // Print new prompt
    if (isatty(0)) {
      Shell::prompt();
    }
}

SimpleCommand * Command::_currentSimpleCommand;
