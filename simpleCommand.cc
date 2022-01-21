#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <regex.h>
#include <sys/types.h>
#include <unistd.h>

#include <iostream>
#include <limits.h>

#include "simpleCommand.hh"

SimpleCommand::SimpleCommand() {
  _arguments = std::vector<std::string *>();
}

SimpleCommand::~SimpleCommand() {
  // iterate over all the arguments and delete them
  for (auto & arg : _arguments) {
    delete arg;
  }
}

void SimpleCommand::insertArgument( std::string * argument ) {
  // simply add the argument to the vector
//_arguments.push_back(argument);
  std::string strnew = *argument;
  char * string = const_cast<char*>(strnew.c_str());

  if (strstr(argument->c_str(), "$") != NULL && strstr(argument->c_str(), "{") != NULL && strstr(argument->c_str(), "}") != NULL) {
    const char * buffer = "^.*${[^}][^}]*}.*$";
    regex_t re;
    if (regcomp(&re, buffer, 0)) {
      perror("regcomp");
      exit(0);
    }

    regmatch_t reg;
    if (!regexec(&re, string, 1, &reg, 0)) {
      char * environm = (char *) calloc(1, sizeof(char) * 1024);
      int i = 0;
      int j = 0;

      while (string[i] != 0 && i < 1024) {
        
        if (strcmp(string, "${$}") == 0) {
          *argument = std::to_string(getpid());
          _arguments.push_back(argument);
          return;
        }
        if (strcmp(string, "${!}") == 0) {
          *argument = std::to_string(getpid());
          _arguments.push_back(argument);
          return;
        }
        if (strcmp(string, "${SHELL}") == 0) {
          char * path = "/u/riker/u92/jeon66/cs252/lab3-src/shell";
          *argument = std::string(path);
          _arguments.push_back(argument);
          return;
        }
        if (string[i] != '$') {
          environm[j] = string[i];
          environm[j+1] = '\0';
          i++;
          j++;

        } else {
          char * env = (char*) calloc(1, sizeof(char) * strlen(string));
          strncat(env, strchr((char *) (string+i), '{') +1, strchr((char*) (string + i), '}') - strchr((char *) (string+i), '{') - 1);

          if (getenv(env) == NULL) {
            strcat(environm, "");
          } else {
            strcat(environm, getenv(env));
          }

          i = i + strlen(env) + 3;
          j = j + strlen(getenv(env));
          free(env);
        }
      }
      string = strdup(environm);
    }
    regfree(&re);
  }

  *argument = std::string(string);
  _arguments.push_back(argument);
}

// Print out the simple command
void SimpleCommand::print() {
  for (auto & arg : _arguments) {
    std::cout << "\"" << *arg << "\" \t";
  }
  // effectively the same as printf("\n\n");
  std::cout << std::endl;
}
