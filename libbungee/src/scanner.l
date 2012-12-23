/*
  scanner.l: bungee's flex scanner

  This file is part of Bungee.

  Copyright 2012 Red Hat, Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

%top{
  /* config.h has _GNU_SOURCE definition. This should be defined before including flex's <stdio.h>. */
#ifdef HAVE_CONFIG_H
# include <config.h>
#endif
}

/* General Flex options. */
%option yylineno noyywrap warn stack

/* Make our scanner and parser re-entrant. This optin tells Bison to
   pass parameters appropriately. */
%option reentrant bison-locations bison-bridge

/* Thread specific local variables are stored in this structure.
   Use "yyget_extra (yyscanner)->" to get access to this structure. */
%option extra-type=" local_vars_t *"

/* Generate header file for all the function definitions. */
/* %option header-file=scanner.h */

/* Start Conditions. */
%x bquote bmlquote brule

/* %option debug */

%{
/* config.h has _GNU_SOURCE definition. This should be defined before including <stdio.h>. */
#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

/* Disable warnings in the flex generated code that are safe to ignore. */
#if defined __GNUC__
# pragma GCC diagnostic ignored "-Wunused-parameter"
# pragma GCC diagnostic ignored "-Wunused-function"
#endif

#ifdef _DEBUG_PARSER /* Support hand-compiled testing for quick debugging. */
# include "parser.tab.h"
#else
# include "parser.h" /* Automake auto-generates parser.h and not default style parser.tab.h */
#endif

/* Uncomment this line instead if you want to DEBUG */
//#define RETURN(val) do { _print_token (val); return val; } while (0)
#define RETURN(val) return val
#define XFREE(ptr) if (ptr) { free (ptr); ptr = NULL;}
#define YYERROR(format, ...)  yyerror (yyget_lloc(yyscanner), yyscanner, format, ##__VA_ARGS__)

/* Handle locations. User action macro is always executed prior to the matched rule's action. */
#define YY_USER_ACTION \
   yyget_lloc (yyscanner)->first_line = yyget_lloc (yyscanner)->last_line = yyget_lineno (yyscanner); \
   yyget_lloc (yyscanner)->first_column = yyget_lloc (yyscanner)->_column; \
   yyget_lloc (yyscanner)->last_column = yyget_lloc (yyscanner)->_column+yyget_leng (yyscanner)-1; \
   yyget_lloc (yyscanner)->_column += yyget_leng (yyscanner)-1;

/* Flex returns this code upon error */
#define YYERRCODE  256

/* Global variables */

/* Error handling routine */
int yyerror (YYLTYPE *yyloc, yyscan_t yyscanner, const char *format, ...) __attribute__ ((format (gnu_printf, 3, 4)));
static inline char *strchrrep (char *str, char find, char rep);
static inline char * strrtrunc (char *str, char ch);
static void unputstrf (yyscan_t yyscanner, const char *format, ...);
static inline char input_ch (yyscan_t yyscanner);
static unsigned int get_indent_len (char *stmt, int len);
static int eat_up_spaces (yyscan_t yyscanner);
static inline void print_token (enum yytokentype val);
%}

%%
\n {
  yyget_lloc (yyscanner)->_column = 1;
  ECHO;
}

\#+[^\n\\]* { /* Comment line. */
   ECHO;
}

\" {
  yyget_extra (yyscanner)->quote.singleline.start = yyget_lineno (yyscanner)+1;
  yyget_extra (yyscanner)->quote.singleline.type = '\"';
  ECHO;
  BEGIN (bquote);
}

\' {
  yyget_extra (yyscanner)->quote.singleline.start = yyget_lineno (yyscanner)+1;
  yyget_extra (yyscanner)->quote.singleline.type = '\'';
  ECHO;
  BEGIN (bquote);
}

<bquote>{
  [^\\\"\'\n]* ECHO;  /* Consume anything that's not a '*' or newline */

  \\\n ; /* Remove newline chars in single quote text */

  \" {    /* End of quote */
    if (yyget_extra (yyscanner)->quote.singleline.type == '\"')
      {
        ECHO;
        yyget_extra (yyscanner)->quote.singleline.type ='\0';
        yyget_extra (yyscanner)->quote.singleline.start = 0;
        BEGIN (INITIAL);
      }
  }

  \' {    /* End of quote */
    if (yyget_extra (yyscanner)->quote.singleline.type == '\'')
      {
        ECHO;
        yyget_extra (yyscanner)->quote.singleline.type ='\0';
        yyget_extra (yyscanner)->quote.singleline.start = 0;
        BEGIN (INITIAL);
      }
    }
  <<EOF>> { /* Unterminated quote */
    if (yyget_extra (yyscanner)->quote.singleline.start != 0)
      return YYERROR ("ERROR: Unterminated quote in line %ld", yyget_extra (yyscanner)->quote.singleline.start);
  }
}

\'\'\' { /* Multi line quote. */
  yyget_extra (yyscanner)->quote.multiline.start = yyget_lineno (yyscanner)+1;
  yyget_extra (yyscanner)->quote.multiline.type = '\'';
  BEGIN (bmlquote);
  ECHO;
}

\"\"\" { /* Multi line quote. */
  yyget_extra (yyscanner)->quote.multiline.start = yyget_lineno (yyscanner)+1;
  yyget_extra (yyscanner)->quote.multiline.type = '\"';
  ECHO;
  BEGIN (bmlquote);
}

<bmlquote>{
  [^\\\'\"]* { /* Multi line quote. */
    ECHO;
  }

  (\'\'\') { /* End of multi line quote. */
    ECHO;
    if (yyget_extra (yyscanner)->quote.multiline.type == '\'')
      {
        yyget_extra (yyscanner)->quote.multiline.type ='\0';
        yyget_extra (yyscanner)->quote.multiline.start = 0;
        BEGIN (INITIAL);
      }
  }

  (\"\"\") { /* End of multi line quote. */
    ECHO;
    if (yyget_extra (yyscanner)->quote.multiline.type == '\"')
      {
        yyget_extra (yyscanner)->quote.multiline.type ='\0';
        yyget_extra (yyscanner)->quote.multiline.start = 0;
        BEGIN (INITIAL);
      }
  }
  <<EOF>> { /* Unterminated quote */
    if (yyget_extra (yyscanner)->quote.multiline.start != 0)
      return YYERROR ("ERROR: Unterminated quote in line %ld", yyget_extra (yyscanner)->quote.multiline.start);
  }
}

^(BEGIN[ \t]*\:) { /* BEGIN: block */
  if (yyget_extra (yyscanner)->found.begin)
    return YYERROR ("Duplicate BEGIN section found.\n");
  yyget_extra (yyscanner)->found.begin = 1;

  RETURN (TBEGIN);
}

[ \t]+BEGIN[ \t]*\: { /* Error Case */
  ECHO;
  return YYERROR ("BEGIN keyword should start at the beginning of line.\n");
}

^(INPUT[ \t]*\:) { /* INPUT: block */
  if (yyget_extra (yyscanner)->found.input)
    return YYERROR ("Duplicate INPUT section found.\n");
  yyget_extra (yyscanner)->found.input = 1;

  RETURN (TINPUT);
}

[ \t]+INPUT[ \t]*\: { /* Error Case */
  ECHO;
  return YYERROR ("INPUT keyword should start at the beginning of line.\n");
}

RULE[ \t]+[^\n]* { /* RULE GroupName->..->SubGroupName->RuleName [Condtion]: */
  /* RULE[ \t]+[a-zA-Z0-9_\-\>]+(([ \t]+[a-zA-Z0-9_]+)|([ \t]*))\:[ \t]*[\n] */

  /* Uses GNU extension to dynamically allocate memory - "%a" prefix.
     Be sure to compile with -D_GNU_SOURCE. */
  int _yylen = strlen (yytext);

  sscanf (yytext, "%*s %as %as",
	  &yyget_extra (yyscanner)->rule.name,
	  &yyget_extra (yyscanner)->rule.condition);

  if (yyget_extra (yyscanner)->rule.condition)
    strrtrunc (yyget_extra (yyscanner)->rule.condition, ':');
  else
    yyget_extra (yyscanner)->rule.condition = strdup ("True");

  yyget_lval (yyscanner)->string = strdup (yyget_extra (yyscanner)->rule.name);
  {
    char *_text;
    asprintf (&_text, "%s\n_A:", yyget_extra (yyscanner)->rule.condition);
    int _yylen_new = strlen (_text);
    strcpy (yytext + _yylen - _yylen_new, _text);
    yyless (_yylen - _yylen_new);
    XFREE (_text);
  }
  BEGIN (brule);
  RETURN (TCONDITION);
}

<brule>{
 _A: { /* Action part of the RULE. */
    yyget_lval(yyscanner)->string = strdup (yyget_extra (yyscanner)->rule.name);

    XFREE (yyget_extra (yyscanner)->rule.name);
    XFREE (yyget_extra (yyscanner)->rule.condition);

    BEGIN (INITIAL);
    RETURN (TACTION);
  }
}

^([ \t]+RULE[ \t]+) { /* Error Case: RULE starting with space. */
  ECHO;
  return YYERROR ("RULE keyword should start at the beginning of line.\n");
}

^(END[ \t]*\:) { /* END: block */
  if (yyget_extra (yyscanner)->found.end)
    return YYERROR ("Duplicate END section found.\n");
  yyget_extra (yyscanner)->found.end = 1;

  RETURN (TEND);
}

[ \t]+END[ \t]*\: { /* Error Case */
  ECHO;
  return YYERROR ("END keyword should start at the beginning of line.\n");
}

\$[a-zA-Z_][a-zA-Z_0-9]* { /* Global variable */
  fprintf (yyget_out (yyscanner), "bungee.globals['%s']", yyget_text (yyscanner)+1);
}

\$\$ { /* Dictionary of all Bungee global variables. */
  fprintf (yyget_out (yyscanner), "bungee.globals");
}

\$\* { /* All field values in a list. */
  fprintf (yyget_out (yyscanner), "bungee.globals.items()");
}

\$\@ { /* All field symbols in a list. */
  fprintf (yyget_out (yyscanner), "bungee.globals.keys()");
}

\$\# { /* Number of fields. */
  fprintf (yyget_out (yyscanner), "len(bungee.globals)");
}

[ \t]+ ECHO;
%%

static inline void
print_token (enum yytokentype val)
{
  switch (val)
    {
      case TBEGIN:
        printf ("<TBEGIN>");
        break;
      case TINPUT:
        printf ("<TINPUT>");
        break;
      case TEND:
        printf ("<TEND>");
        break;
      default:
        printf ("<UNDEFINED>");
    }
}


/* Replace all occurances of char 'find' with char 'rep' in string 'str'. */
static inline char *
strchrrep (char *str, char find, char rep)
{
  int i=0;
  if (!str || !str[0])
    return NULL;

  while (str[i])
    {
      if (str[i] == find)
	str[i]=rep;
      i++;
    }
  return str;
}

/* Unput string back to Flex's input buffer. Arguments works like printf.
 Note: You cannot write back more than the current length of yytext. */
static void
unputstrf (yyscan_t yyscanner, const char *format, ...)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;
  int i=0;
  char *str;
  va_list ap;

  if (!format)
    return;

  va_start (ap, format);
  vasprintf (&str, format, ap);
  va_end (ap);

  if (!str)
    return;

  i = strlen (str);

  while (str[i])
    {
      unput (str[i]);
      i--;
    }
  free (str);
}

/* Lex's input() wrapper to safely handle location tacking */
static inline char
input_ch (yyscan_t yyscanner)
{
  yyget_lloc (yyscanner)->_column++;;
  return input (yyscanner);
}

static int
eat_up_spaces (yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;
  register int ch;

  for (;;)
    {
      ch = input_ch (yyscanner);
      if ((ch == ' ') || (ch == '\t'))
	  continue;
      else if (ch == EOF)
	return YYERROR ("Unexpected end of file while eating spaces.\n");
      else
	{
	  unput (ch);
	  break;
	}
    }
  return 0;
}

static unsigned int
get_indent_len (char *stmt, int len)
{
  unsigned int indent_len, i;
  for (indent_len=0, i=0; i < len; i++)
    {
      if ((stmt[i] == ' ') || (stmt[i] == '\t'))
        indent_len++;
      else
	return indent_len;
    }
  return indent_len;
}

static inline char *
strrtrunc (char *str, char ch)
{
  char *_str = strrchr (str, ch);
  if (_str)
    str[_str-str]='\0';
  return str;
}

int
yyerror (YYLTYPE *_yylloc, yyscan_t yyscanner, char const *format, ...)
{
  if (!format)
    return YYERRCODE;

  local_vars_t *locals = yyget_extra (yyscanner);
  if (locals->err_fp)
    {
      va_list ap;
      va_start (ap, format);

      if (locals->script_name && locals->script_name[0])
	fprintf (locals->err_fp, "ERROR[%s:%d]: ", locals->script_name, yyget_lineno (yyscanner));
      else
	fprintf (locals->err_fp, "ERROR[line %d]: ", yyget_lineno (yyscanner));
      vfprintf (locals->err_fp, format, ap);

      va_end (ap);
    }
  // exit (1);
  return YYERRCODE;
}

#if 0
int
main ()
{
  yylex ();
}
#endif
