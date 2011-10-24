/*
 * Copyright (C) 2011 Marcin Kościelnicki <koriakin@0x04.net>
 * All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * VA LINUX SYSTEMS AND/OR ITS SUPPLIERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

%{
#include "ed2_misc.h"
#include "ed2_parse.h"
#include "ed2i.h"
#include "ed2i_pre.h"
#include "ed2i_parse.h"
#include "ed2i_lex.h"
#include <stdio.h>
void ed2i_error (YYLTYPE *loc, yyscan_t lex_state, struct ed2i_isa **isa, char const *err) {
	fprintf (stderr, ED2_LOC_FORMAT(*loc, "%s\n"), err);
}

%}

%locations
%define api.pure
%name-prefix "ed2i_"
%lex-param { yyscan_t lex_state }
%parse-param { yyscan_t lex_state }
%parse-param { struct ed2i_isa **isa }

%union {
	uint64_t num;
	char *str;
	struct ed2_astr astr;
	struct {
		char **strs;
		int strsnum;
		int strsmax;
	} strs;
	struct ed2ip_feature *feature;
	struct ed2ip_variant *variant;
	struct ed2ip_mode *mode;
	struct ed2ip_modeset *modeset;
	struct ed2ip_opfield *opfield;
	struct ed2ip_enumval *enumval;
	struct ed2ip_isa *isa;
}

/* XXX: destructors */

%token <str> T_WORD
%token <str> T_LBSTR
%token <str> T_REG
%token <astr> T_STR
%token <num> T_NUM
%token T_ERR
%token T_UMINUS
%token T_PLUSPLUS "++"
%token T_MINUSMINUS "--"
%token T_PLUSEQ "+="
%token T_MINUSEQ "-="
%token T_SHL "<<"
%token T_FEATURE "FEATURE"
%token T_CONFLICT "CONFLICT"
%token T_IMPLIES "IMPLIES"
%token T_VARIANT "VARIANT"
%token T_MODE "MODE"
%token T_DEFAULT "DEFAULT"
%token T_OPFIELD "OPFIELD"
%token T_ENUM "ENUM"
%token T_BITS "BITS"
%token T_FUNC "FUNC"
%token T_SWITCH "SWITCH"
%token T_EXPR "EXPR"
%token T_IMM "IMM"
%token T_MEM "MEM"
%token T_SEGMENT "SEGMENT"
%token T_SEX "SEX"
%token T_ZEX "ZEX"
%token T_TSAEX "TSAEX"
%token T_OEX "OEX"
%token T_SIGNED "SIGNED"
%token T_UNSIGNED "UNSIGNED"
%token T_MOD "MOD"
%token T_PCREL "PCREL"
%token T_START "START"
%token T_END "END"
%token T_READ "READ"
%token T_LET "LET"
%token T_SEQ "SEQ"
%token T_LE "LE"
%token T_BE "BE"
%token T_ARG "ARG"
%token T_IGROUP "IGROUP"
%token T_INSN "INSN"
%token T_CONST "CONST"
%token T_OPTIONAL "OPTIONAL"
%token T_VECTOR "VECTOR"
%token T_NOP "NOP"
%token T_ENDMARK "ENDMARK"
%token T_FLAG "FLAG"
%token T_BTARG "BTARG"
%token T_CTARG "CTARG"
%token T_LIT "LIT"

%type <str> strnn
%type <str> description
%type <strs> wordsnz
%type <feature> feature
%type <feature> fmods
%type <variant> variant
%type <variant> vmods
%type <modeset> modeset
%type <modeset> modes
%type <modeset> msmods
%type <mode> mode
%type <mode> memods
%type <opfield> opfield
%type <opfield> opfmods
%type <opfield> enumvals
%type <enumval> enumval
%type <isa> file

%destructor { free($$); } <str>
%destructor { free($$.str); } <astr>
%destructor { ed2_free_strings($$.strs, $$.strsnum); } <strs>
%destructor { ed2ip_del_feature($$); } <feature>
%destructor { ed2ip_del_variant($$); } <variant>
%destructor { ed2ip_del_mode($$); } <mode>
%destructor { ed2ip_del_modeset($$); } <modeset>
%destructor { ed2ip_del_opfield($$); } <opfield>
%destructor { ed2ip_del_enumval($$); } <enumval>
%destructor { ed2ip_del_isa($$); } <isa>

%%

start:	file		{ *isa = ed2ip_transform($1); }

file:	/**/		{ $$ = calloc(sizeof *$$, 1); }
|	file feature	{ $$ = $1; ADDARRAY($$->features, $2); }
|	file variant	{ $$ = $1; ADDARRAY($$->variants, $2); }
|	file modeset	{ $$ = $1; ADDARRAY($$->modesets, $2); }
|	file opfield	{ $$ = $1; ADDARRAY($$->opfields, $2); }
|	file func
|	file exprdef
|	file argdef
|	file moddef
|	file seqdef
|	file insndef
|	file igroup
|	file error ';'	{ $$ = $1; $$->broken = 1; }
;

feature:	"FEATURE" wordsnz description fmods ';'	{ $$ = $4; $$->loc = @$; $$->description = $3; $$->names = $2.strs; $$->namesnum = $2.strsnum; $$->namesmax = $2.strsmax; }
;

fmods:		/**/	{ $$ = calloc(sizeof *$$, 1); }
|		fmods "CONFLICT" wordsnz { int i; $$ = $1; for (i = 0; i < $3.strsnum; i++) ADDARRAY($$->conflicts, $3.strs[i]); free($3.strs); }
|		fmods "IMPLIES" wordsnz { int i; $$ = $1; for (i = 0; i < $3.strsnum; i++) ADDARRAY($$->implies, $3.strs[i]); free($3.strs); }
;

wordsnz:	T_WORD { memset(&$$, 0, sizeof($$)); ADDARRAY($$.strs, $1); }
|		wordsnz T_WORD { $$ = $1; ADDARRAY($$.strs, $2); }
;

description:	/**/	{ $$ = 0; }
|		strnn
;

variant:	"VARIANT" wordsnz description vmods ';'	{ $$ = $4; $$->loc = @$; $$->description = $3; $$->names = $2.strs; $$->namesnum = $2.strsnum; $$->namesmax = $2.strsmax; }
;

vmods:		/**/	{ $$ = calloc(sizeof *$$, 1); }
|		vmods "FEATURE" wordsnz { int i; $$ = $1; for (i = 0; i < $3.strsnum; i++) ADDARRAY($$->features, $3.strs[i]); free($3.strs); }
;


modeset:	"MODE" wordsnz description msmods '{' modes '}' ';' { $$ = $4; $$->names = $2.strs; $$->namesnum = $2.strsnum; $$->namesmax = $2.strsmax; $$->description = $3; $$->modes = $6->modes; $$->modesnum = $6->modesnum; $$->modesmax = $6->modesmax; free($6); }
;

modes:		modes mode { $$ = $1; ADDARRAY($$->modes, $2); }
|		/**/	{ $$ = calloc(sizeof *$$, 1); }
;

msmods:		/**/	{ $$ = calloc(sizeof *$$, 1); }
|		msmods "OPTIONAL" { $$ = $1; $$->isoptional = 1; }
;

mode:		wordsnz description memods ';' { $$ = $3; $$->loc = @$; $$->description = $2; $$->names = $1.strs; $$->namesnum = $1.strsnum; $$->namesmax = $1.strsmax; }
;

memods:		/**/	{ $$ = calloc(sizeof *$$, 1); }
|		memods "FEATURE" wordsnz { int i; $$ = $1; for (i = 0; i < $3.strsnum; i++) ADDARRAY($$->features, $3.strs[i]); free($3.strs); }
|		memods "DEFAULT" { $$ = $1; $$->isdefault = 1; }
;

strnn:		T_STR	{ $$ = $1.str; if (strlen($$) != $1.len) YYERROR; }
;

opfield:	"OPFIELD" T_WORD T_NUM opfmods ';' { $$ = $4; $$->name = $2; $$->len = $3; }
|		"OPFIELD" T_WORD "ENUM" '{' enumvals '}'  opfmods ';'	{ $$ = $7; $$->name = $2; $$->enumvals = $5->enumvals; $$->enumvalsnum = $5->enumvalsnum; $$->enumvalsmax = $5->enumvalsmax; free($5); }
;

func:		"FUNC" T_WORD T_NUM funcval ';'
|		"FUNC" T_WORD "ENUM" '{' enumvals '}' funcval ';'
;

enumvals:	enumvals enumval	{ $$ = $1; ADDARRAY($$->enumvals, $2); }
|		/**/	{ $$ = calloc(sizeof *$$, 1); }
;

enumval:	T_WORD ';'	{ $$ = calloc(sizeof *$$, 1); $$->name = $1; }
|		T_WORD "DEFAULT" ';'	{ $$ = calloc(sizeof *$$, 1); $$->name = $1; $$->isdefault = 1; }
;

opfmods:	/**/	{ $$ = calloc(sizeof *$$, 1); }
|		opfmods "DEFAULT" T_NUM	{ $$ = $1; if ($$->hasdef) { fprintf(stderr, ED2_LOC_FORMAT(@$, "Redefined default value\n")); /* XXX */ } $$->defval = $3; $$->hasdef = 1; }
|		opfmods "BITS" '{' opfbitfields '}'	{ $$ = $1; fprintf(stderr, "OPFIELD BITS\n"); /*abort(); XXX */ }
;

opfbitfields:	opfbitfields opfbitfield
|		/**/
;


opfbitfield:	T_NUM T_WORD ';'
|		T_NUM ':' T_NUM T_WORD ';'
;

funcval:	bitfconst
|		"SWITCH" '{' funccases '}'
;

funccases:	funccases case funcval ';'
|		/* */
;

exprdef:	"EXPR" T_WORD fexpr ';'
;

argdef:		"ARG" T_WORD arg ';'
;

arg:		"SWITCH" '{' argcases '}'
|		qmods expr
;

argcases:	argcases case arg ';'
|		/* */
;

fexpr:		"SWITCH" '{' exprcases '}'
|		expr
;

expr:		expr '+' expr6
|		expr6
;

expr6:		expr6 '*' expra
|		expra
;

expra:		"MEM" '(' expr memmods ')'
|		"IMM" '(' bitfield immmods ')'
|		T_WORD
|		T_REG
|		T_REG '[' bitfield regmods ']'
|		T_NUM
|		T_UMINUS T_NUM
|		'#'
;

regmods:	/* */
|		regmods "<<" T_NUM
|		regmods '+' T_NUM
|		regmods "VECTOR" T_NUM
;

memmods:	/* */
|		memmods "SEGMENT" expr
|		memmods "LIT"
|		memmods "+="  expr
|		memmods "-="  expr
|		memmods "++"  expr
|		memmods "--"  expr
|		memmods qmod
;

immmods:	/* */
|		immmods "SEX" T_NUM
|		immmods "ZEX" T_NUM
|		immmods "TSAEX" T_NUM
|		immmods "OEX" T_NUM
|		immmods "SIGNED"
|		immmods "UNSIGNED"
|		immmods "BTARG"
|		immmods "CTARG"
|		immmods "<<" T_NUM
|		immmods '+' T_NUM
|		immmods '-' T_NUM
|		immmods "PCREL" "END"
|		immmods "PCREL" "START" /* XXX: anchors? */
|		immmods "PCREL" '(' pcrelmods ')'
;

pcrelmods:	"START"
|		"END"
|		pcrelmods '&' T_NUM
|		pcrelmods '&' '-' T_NUM
|		pcrelmods '+' T_NUM
|		pcrelmods '-' T_NUM
;

exprcases:	exprcases case fexpr ';'
|		/* */
;

moddef:		"MOD" T_WORD mods ';'
;

qmods:		qmods qmod
|		/* */
;

mods:		mods mod
|		/* */
;

mod:		"SWITCH" '{' modcases '}'
|		qmod
;

qmod:		"MOD" T_WORD
|		"FLAG" '(' bitfield T_STR ')'
|		"FLAG" '(' bitfield T_STR T_STR ')'
|		T_STR
|		T_LBSTR ']'
;

modcases:	modcases case mods ';'
|		/* */
;

igroup:		"IGROUP" T_WORD fbinsn ';'
;

fbinsn:		"SWITCH" '{' binsncases '}'
|		binsn mods
;

binsncases:	binsncases case fbinsn ';'
|		/* */
;

binsn:		T_STR
|		"IGROUP" T_WORD
;

insn:		binsn args qmods imods
|		"SWITCH" '{' insncases '}'
;

imods:		/* */
|		imods "NOP"
|		imods "ENDMARK"
;

insncases:	insncases case insn ';'
|		insncases error ';'
|		/* */
;

args:		args arg
|		/**/
;

insndef:	"INSN" T_WORD insn ';'
;

seqdef:		"SEQ" T_WORD seq ';'
;

seq:		"SWITCH" '{' seqcases '}'
|		'{' seqs '}'
|		"READ" T_WORD
|		"READ" "LE" T_WORD
|		"READ" "BE" T_WORD
|		"LET" bitfield '=' bitfconst
|		"SEQ" T_WORD
|		"INSN" insn
|		"INSN" T_WORD
;

bitfconst:	bitfield
|		"CONST" T_NUM
|		"CONST" T_WORD
;

seqcases:	seqcases case seqs
|		/* */
;

seqs:		seqs seq ';'
|		seqs error ';'
|		/* */
;

case:		caseparts ':'
;

caseparts:	caseparts casepart
|		/* */
;

casepart:	"MODE" cmodelist
|		"FEATURE" cfeatlist
|		bitfield cmatchlist
;

cmodelist:	T_WORD
|		cmodelist '|' T_WORD
;

cfeatlist:	T_WORD
|		cfeatlist '&' T_WORD
;

cmatchlist:	cmatchvar
|		cmatchlist '|' cmatchvar
;

cmatchvar:	T_WORD	/* for enums */
|		T_NUM
|		T_NUM '/' T_NUM
|		T_NUM '-' T_NUM
|		T_NUM '-' T_NUM '/' T_NUM
;

bitfield:	bitchunk
|		bitfield '#' bitchunk
;

bitchunk:	T_WORD
|		T_WORD '[' T_NUM ']'
|		T_WORD '[' T_NUM ':' T_NUM ']'
;

%%

struct ed2i_isa *ed2i_read_isa (const char *isaname) {
	FILE *file = ed2_find_file(isaname, getenv("ED2_PATH"), 0); 
	if (!file)
		file = ed2_find_file(isaname, ".:isadb:../isadb:envytools/isadb", 0);
	if (!file) {
		fprintf (stderr, "Cannot find ISA definition file for ISA %s.\n", isaname);
		fprintf (stderr, "Please set ED2_PATH to point to the isadb directory from envytools.\n");
		return 0;
	}
	yyscan_t lex_state;
	struct ed2_lex_intern lex_extra;
	struct ed2i_isa *isa;
	lex_extra.line = 1;
	lex_extra.pos = 1;
	lex_extra.ws = 0;
	lex_extra.file = isaname;
	lex_extra.nest = 0;
	ed2i_lex_init_extra(lex_extra, &lex_state);
	ed2i_set_in(file, lex_state);
	int res = ed2i_parse(lex_state, &isa);
	ed2i_lex_destroy(lex_state);
	fclose(file);
	if (res)
		return 0;
	return isa;
}
