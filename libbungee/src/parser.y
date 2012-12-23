/*
  parser.y: bungee's bison parser

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

/*** Bison declarations ***/
/* Start symbol */
%start program
%define api.pure
%error-verbose
%locations

/* Terminal value type */
%union {
  char *string;
}

/** Terminal symbols **/
/* Terminal symbols with no value */
%token TBEGIN TINPUT TEND TEOF
/* Terminal symbols with string value */
%token <string> TCONDITION TACTION

/*  Free heap based token values during error recovery */
%destructor { XFREE ($$); } <string>

/* Pass the argument to yyparse through to yylex. */
%parse-param {yyscan_t yyscanner}
%lex-param   {yyscan_t yyscanner}

/* C declarations */
%initial-action {
#ifndef _DEBUG_PARSER
  bindtextdomain ("bison-runtime", BISON_LOCALEDIR);
#endif
}

%code top {
#include <libintl.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
}

%code provides {
/* Compile .bng source to .bngo format */
int bng_compile (FILE *script_fp, const char *script_name, FILE *out_fp, FILE *err_fp);
}

%code requires {
  typedef struct {
    FILE *err_fp;
    const char *script_name;
    union {
      struct {
	unsigned long start;
	unsigned char type;
      } multiline;
      struct {
	unsigned long start;
	unsigned char type;
      } singleline;
    } quote;
    struct {
      unsigned char begin;
      unsigned char input;
      unsigned char end;
    } found;
    struct {
      char *name;
      char *condition;
    } rule;
  } local_vars_t;

/* Terminal location type */
typedef struct YYLTYPE {
  int _column;
  int first_line;
  int first_column;
  int last_line;
  int last_column;
} YYLTYPE;
# define YYLTYPE_IS_DECLARED 1 /* alert the parser that we have our own definition */
}

%code {
#define XFREE(ptr) if (ptr) { free (ptr); ptr = NULL;}
#define _PAD_SPACES(num) do { int i; for (i=1; i<num; i++) putchar (' '); } while (0)

/* Flex generates all the header definitions for us. */
#include "scanner.h"

extern int  yyerror (YYLTYPE *yylloc, yyscan_t yyscanner, char const *format, ...) __attribute__ ((format (gnu_printf, 3, 4)));

}

/* Grammar Rules */
%%
program: | program section
section: begincb | inputcb | rule | endcb

begincb:
TBEGIN
{
  fprintf (yyget_out (yyscanner), "def BEGIN():");
}

inputcb:
TINPUT
{
  fprintf (yyget_out (yyscanner), "def INPUT():");
}

rule: condition action

condition: TCONDITION
{
  if ($1 == NULL)
    {
      // YYERROR ("RULE has no name.\n");
      YYABORT;
    }

  fprintf (yyget_out (yyscanner), "def _CONDITION_%s()\n    return ", $1);
  XFREE ($1);
}

action: TACTION
{
  if ($1 == NULL)
    {
      //      YYERROR ("RULE has no name.\n");
      YYABORT;
    }

  fprintf (yyget_out (yyscanner), "\ndef _ACTION_%s()", $1);
  /* Now we have both the corresponding condition and action functions
     given a rule name. */
  /* fprintf (yyget_out (yyscanner),
	   "Rules.append('%s', _ACTION_%s, _CONDITION_%s)\n",
	   $1, $1, $1);
  */
  XFREE ($1);
}

endcb:
TEND
{
  fprintf (yyget_out (yyscanner), "def END():");
}
| error
{
  YYABORT;
}

%%

int
bng_compile (FILE *script_fp, const char *script_name, FILE *out_fp, FILE *err_fp)
{
  int status;
  yyscan_t yyscanner; /* Re-entrant praser stores its state here. */
  local_vars_t locals;

  locals.quote.singleline.type = locals.quote.multiline.type='\0';
  locals.quote.singleline.start = locals.quote.multiline.start = 0;
  locals.found.begin = locals.found.input = locals.found.end = 0;
  locals.err_fp = stderr;
  locals.script_name = script_name; /* Used by yyerror to relate error messages to script. */

  if (yylex_init_extra (&locals, &yyscanner) != 0)
    return 1;

  if (script_fp == NULL)
    yyset_in (stdin, yyscanner);
  else
    yyset_in (script_fp, yyscanner);

  if (out_fp == NULL)
    yyset_out (stdout, yyscanner);
  else
    yyset_out (out_fp, yyscanner);

  if (yyparse (yyscanner) == 0)
    status = 0;
  else
    status = 1;

  yylex_destroy (yyscanner);

  return status;
}

#ifdef _DEBUG_PARSER
int
main (int argc, char *argv[])
{
  FILE *fp = fopen (argv[1], "r");
  //return  bng_compile (NULL, NULL, NULL, NULL);
  return bng_compile (fp, argv[1], stdout, stderr);
}

#endif
