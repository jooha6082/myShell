
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires 
{
#include <string>
#include <regex.h>
#include <dirent.h>
#include <algorithm>
#include <cstring>
#include <iostream>


#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token NOTOKEN GREAT NEWLINE WORD LESS GREATGREAT GREATAMPERSAND GREATGREATAMPERSAND PIPE AMPERSAND TWOGREAT

%{
//#define yylex yylex
#include <cstdio>
#include "shell.hh"
#include <cstring>
#include <string>
#include <iostream>

void expandWildcardsIfNecessary(std::string * arg);
void expandWildcard(char * prefix, char * suffix);
int cmpfunc(char *x, char *y);
static std::vector<char *> sorted = std::vector<char *>();
static bool flag;

void yyerror(const char * s);
int yylex();

%}

%%

goal:
  commands
  ;

commands:
  command
  | commands command
  ;

command: simple_command
       ;

simple_command:
  pipe_list iomodifier_list background_opt NEWLINE {
    //printf("   Yacc: Execute command\n");
    Shell::_currentCommand.execute();
  }
  | NEWLINE {
    Shell::_currentCommand.execute();
  }
  | error NEWLINE { yyerrok; }
  ;

command_and_args:
  command_word argument_list {
    Shell::_currentCommand.
    insertSimpleCommand( Command::_currentSimpleCommand );
  }
  ;

argument_list:
  argument_list argument
  | /* can be empty */
  ;

argument:
  WORD {
    //printf("   Yacc: insert argument \"%s\"\n", $1->c_str());
    //Command::_currentSimpleCommand->insertArgument( $1 );

    char *pre = (char *)"";
    flag = false;
    expandWildcard(pre, (char *)$1->c_str());
    std::sort(sorted.begin(), sorted.end(), cmpfunc);
    for (auto x: sorted) {
      std::string * insert = new std::string(x);
      Command::_currentSimpleCommand->insertArgument(insert);
    }
    sorted.clear();
  }
  ;

command_word:
  WORD {
    //printf("   Yacc: insert command \"%s\"\n", $1->c_str());
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument( $1 );
  }
  ;

pipe_list:
  pipe_list PIPE command_and_args
  | command_and_args
  ;

iomodifier_opt:
  GREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._count++;
  }
  | GREATGREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._append = true;
    Shell::_currentCommand._outFile = $2;
  }
  | GREATAMPERSAND WORD {
  //  printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = new std::string($2->c_str());
  }
  | GREATGREATAMPERSAND WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._append = true;
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = new std::string($2->c_str());
  }
  | LESS WORD {
  //  printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._inFile = $2;
  }
  | TWOGREAT WORD {
//    printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._errFile = $2;
  }
  /* can be empty */ 
  ;

iomodifier_list:
  iomodifier_list iomodifier_opt
  |
  ;

background_opt:
  AMPERSAND {
    Shell::_currentCommand._background = true;
  }
  |
  ;

%%

void expandWildcardsIfNecessary(std::string * arg) {
  char * args = (char *)arg->c_str();

  if (strchr(args, '*') == NULL && strchr(args, '?') == NULL) {
    Command::_currentSimpleCommand->insertArgument(arg);
    return;
  }

  std::string local;
  char * a;
  DIR * dir;
  if (args[0] == '/') {
    std::size_t searched = arg->find('/');
    while (arg->find('/', searched+1) == std::string::npos) {
      searched = arg->find('/', searched+1);
    }
    local = arg->substr(0, searched+1);
    a = (char *)arg->substr(searched+1, -1).c_str();
    dir = opendir(local.c_str());
  } else {
    dir = opendir(".");
    a = args;
  }

  if (dir == NULL) {
    perror("opendir");
    return;
  }
  
  char * reg = (char*)malloc(strlen(args)*2 +10);
  char * r = reg;
  *(r++) = '^';
  while (*a) {
    if (*a == '*') {
      *(r++) = '.';
      *(r++) = '*';
    } else if (*a = '?') {
      *(r++) = '.';
    } else if (*a = '.') {
      *(r++) = '\\';
      *(r++) = '.';
      *(r++) = *a;
    }
    a++;
  }
  *(r++) = '$';
  *r = 0;

  regex_t re;
  int expbuf = regcomp(&re, reg, REG_EXTENDED|REG_NOSUB);
  if (expbuf != 0) {
    perror("regcomp");
    return;
  }

  struct dirent * ent;
  std::vector<char *> sorting = std::vector<char *>();
  while((ent=readdir(dir)) != NULL) {
    if (regexec(&re, ent->d_name, 1, NULL, 0) == 0) {
      if(reg[1] != '.') {
        std::string chars(ent->d_name);
        chars = chars + local;
        sorting.push_back(strdup((char *)chars.c_str()));
      } else {
        if (ent->d_name[0] != '.') {
          std::string chars(ent->d_name);
          chars = chars + local;
          sorting.push_back(strdup((char *)chars.c_str()));
        }
      }
    }
  }
  regfree(&re);
  closedir(dir);

  std::sort(sorting.begin(), sorting.end(), cmpfunc);

  for (auto x: sorting) {
    std::string * insert = new std::string(x);
    Command::_currentSimpleCommand->insertArgument(insert);
  }
  sorting.clear();
}

int cmpfunc (char *x,  char  *y) {
  return strcmp(x, y) < 0;
}

void expandWildcard(char * prefix, char * suffix) {
  if (suffix[0] == 0) {
    sorted.push_back(strdup(prefix));
    return;
  }
  char c[1024];
  if (prefix[0] == 0) {
    if (suffix[0] != '/') {
      strcpy(c, prefix);
    } else {
      suffix += 1;
      sprintf(c, "%s/", prefix);
    }
  } else {
    sprintf(c, "%s/", prefix);
  }

  char component[1024];
  char * s = strchr(suffix, '/');
  if (s != NULL) {
    strncpy(component, suffix, s-suffix);
    component[s-suffix] = 0;
    suffix = s+1;
  } else {
    strcpy(component, suffix);
    suffix = suffix + strlen(suffix);
  }

  char newprefix[1024];
  if (strchr(component, '?') == NULL & strchr(component, '*') == NULL) {
    if (c[0] != 0) {
      sprintf(newprefix, "%s/%s", prefix, component);
    } else {
      strcpy(newprefix, component);
    }
    expandWildcard(newprefix, suffix);
    return;
  }

  char * reg = (char *)malloc(strlen(component)*2 +10);
  char * r = reg;
  *(r++) = '^';
  int n = 0;
  while (component[n]) {
    if (component[n] == '*') {
      *(r++) = '.';
      *(r++) = '*';
    } else if (component[n] == '?') {
      *(r++) = '.';
    } else if (component[n] == '.') {
      *(r++) = '\\';
      *(r++) = '.';
    } else {
      *(r++) = component[n];
    }
    n++;
  }
  *(r++) = '$';
  *r = 0;

  regex_t re;
  int expbuf = regcomp(&re, reg, REG_EXTENDED|REG_NOSUB);

  char * dir;
  if (c[0] == 0) {
    dir = (char*)".";
  } else {
    dir = c;
  }
  DIR * d = opendir(dir);
  if (d == NULL) {
    return;
  }

  bool flag = false;
  struct dirent * ent;
  while ((ent = readdir(d)) != NULL) {
    if (regexec(&re, ent->d_name, 1, NULL, 0) == 0) {
      flag = true;
      if (c[0] != 0) {
        sprintf(newprefix, "%s/%s", prefix, ent->d_name);
      } else {
        strcpy(newprefix, ent->d_name);
      }
      if (reg[1] != '.') {
          expandWildcard(newprefix, suffix);
      } else {
        if (ent->d_name[0] != '.') {
          expandWildcard(newprefix, suffix);
        }
      }
    }
  }
  if (flag == false) {
    if (c[0] != 0) {
      sprintf(newprefix, "%s/%s", prefix, component);
    } else {
      strcpy(newprefix, component);
    }
    expandWildcard(newprefix, suffix);
  }
  regfree(&re);
  free(reg);
  closedir(d);

}

void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}

#if 0
main()
{
  yyparse();
}
#endif
