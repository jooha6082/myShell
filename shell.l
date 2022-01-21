
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%x sour

%{

#include <cstring>
#include <string.h>
#include "y.tab.hh"
#include <unistd.h>

extern "C" char * read_line();

int mygetc(FILE *f) {
  static char *p;
  char ch;

  if (!isatty(0)) {
    return getc(f);
  }
  if (p == NULL || *p == 0) {
    char *s = read_line();
    p = s;
  }
  ch = *p;
  p++;
  return ch;
}

#undef getc
#define getc(f) mygetc(f)

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
  unput(c);
}

%}

%option noyywrap

%%

\n {
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

">>&" {
  return GREATGREATAMPERSAND;
}

">&" {
  return GREATAMPERSAND;
}

"2>" {
  return TWOGREAT;
}

">>" {
  return GREATGREAT;
}

">" {
  return GREAT;
}

"<" {
  return LESS;
}

"&" {
  return AMPERSAND;
}

"|" {
  return PIPE;
}

\"[^\n\"]*\" {
  std::string text = std::string(yytext);
  text = text.substr(1, text.length() - 2);
  yylval.cpp_string = new std::string(text);
  return WORD;
}

~[^ \n\t]* {
  std::string text = std::string(yytext);
  if (text.length() == 1) {
    yylval.cpp_string = new std::string(getenv("HOME"));
  } else {
    if (text.find("/") != std::string::npos) {
      text = std::string("/homes/")  + text.substr(1, text.length()-1);
      yylval.cpp_string = new std::string(text);
    } else {
      text = std::string("/homes/") + text.substr(1, text.length()-1);
      yylval.cpp_string = new std::string(text);
    }
  }
  return WORD;
}

source {
  BEGIN(sour);
}

<sour>[^ \t\n][^ \t\n]* {
  FILE * yyin = fopen(yytext, "r");
  if (!yyin) {
    perror("fopen");
    BEGIN(INITIAL);
  }
  yypush_buffer_state(yy_create_buffer(yyin, YY_BUF_SIZE));
  BEGIN(INITIAL);
  yyparse();
  yypop_buffer_state();
  fclose(yyin);
}

[$]+[{]+[a-z]+[}] {
  std::string text = std::string(yytext);
  text = text.substr(2, text.length() - 3);
  std::string compiled = getenv(text.c_str());
  yylval.cpp_string = new std::string(compiled);
  return WORD;
}

$\([^\n]*\)|\`[^\n\`]*\` {
  std::string text = std::string(yytext);
  //printf("before: %s\n", text.c_str());
  if (text.find("$") != std::string::npos) {
    text = text.substr(1, text.length()-1);
  }
  text = text.substr(1, text.length()-2);
  text = text + "\nexit\n";
  //printf("before: %s\n", text.c_str());
  //text = text + '\0';
//  printf("text; %s\n", text.c_str());
  char * readbuffer = ((char *) malloc(sizeof(char) * 1024));

  int infd;
  int outfd;
  infd = dup(0);
  outfd = dup(1);

  int pin[2];
  int pout[2];
  pipe(pin);
  pipe(pout);

  dup2(pin[0], 0);
  dup2(pout[1], 1);
  close(pin[0]);
  close(pout[1]);

  write(pin[1], text.c_str(), text.length());

  close(pin[1]);

  int ret;
  ret = fork();
  if (ret == 0){

    const char * path = "/proc/self/exe";
    char ** argument = new char*[strlen(path) + 1];
    execvp(path, argument);
    perror("excvp");
    exit(1);

  } else if (ret < 0) {
    perror("fork");
    exit(1);
  }  // waitpid(ret, NULL, 0);
  dup2(infd, 0);
  dup2(outfd, 1);
  close(infd);
  close(outfd);

  char reading;
  int i = 0;
  while (read(pout[0], &reading, 1)) {
    if (reading == '\n') {
      readbuffer[i++] = ' ';
    } else {
      readbuffer[i++] = reading;
    }
  }
  readbuffer[i] = '\0';
  //close(pout[0]);
  //printf("rbuffer: %s, nbytes: %d\n", readbuffer, nbytes);
  for (i = strlen(readbuffer) - 12; i >= 0; i--) {
    unput(readbuffer[i]);
  }

}

[^ \t\n><|&]*\\[^ \t\n]* {
  int length = strlen(yytext);
  char * text = ((char *) malloc(sizeof(char) * length));
  char * original = yytext;
  int j = 0;
  for (int i = 0; i != strlen(original); i++) {
    if (original[i] == '\\') {
      if (original[i+1] == '\\') {
        text[j] = original[i+1];
        i++;
        j++;
      }
    } else {
      text[j] = original[i];
      j++;
    }
  }

  yylval.cpp_string = new std::string(text);

  return WORD;
}

[^ \t\n][^ \t\n]*  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}
