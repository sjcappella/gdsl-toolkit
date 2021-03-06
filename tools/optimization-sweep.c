/* vim:cindent:ts=2:sw=2:expandtab */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <getopt.h>
#include <unistd.h>
#include <gdsl.h>
#include <sys/resource.h>

#include <err.h>
#include <fcntl.h>
#include <gelf.h>
#include <string.h>
#include <sysexits.h>

#include <time.h>

#include <gdsl_elf.h>

#define NANOS 1000000000LL

enum p_option {
  OPTION_ELF, OPTION_OFFSET, OPTION_SINGLE, OPTION_CHILDREN, OPTION_FILE, OPTION_CLEANUP, OPTION_LATEX, OPTION_LIVENESS, OPTION_FSUBST, OPTION_CHAIN
};

enum mode {
  MODE_SINGLE, MODE_DEFAULT, MODE_CHILDREN
};

struct options {
  char elf;
  size_t offset;
  enum mode mode;
  char **files;
  size_t files_size;
  size_t files_length;
  char cleanup;
  char latex;

  char liveness;
  char fsubst;
  char chain;
};

static char args_parse(int argc, char **argv, struct options *options) {
  options->elf = 0;
  options->offset = 0;
  options->mode = MODE_DEFAULT;
  options->files_size = 8;
  options->files = (char**)malloc(sizeof(char*) * options->files_size);
  options->files_length = 0;
  options->cleanup = 0;
  options->latex = 0;
  options->liveness = 0;
  options->fsubst = 0;
  options->chain = 0;

  struct option long_options[] =
      { { "elf", no_argument, NULL, OPTION_ELF }, { "offset", required_argument, NULL, OPTION_OFFSET }, { "children",
      no_argument, NULL, OPTION_CHILDREN }, { "single", no_argument, NULL, OPTION_SINGLE }, { "file", required_argument,
      NULL, OPTION_FILE }, { "cleanup", no_argument, NULL, OPTION_CLEANUP }, { "latex", no_argument,
      NULL, OPTION_LATEX }, { "liveness", no_argument, NULL, OPTION_LIVENESS }, { "fsubst", no_argument, NULL,
          OPTION_FSUBST}, { "chain", no_argument, NULL, OPTION_CHAIN}, {NULL, 0, NULL, 0}};

  while(1) {
    int result = getopt_long(argc, argv, "", long_options, NULL);
    if(result < 0) break;
    switch(result) {
      case OPTION_ELF: {
        options->elf = 1;
        break;
      }
      case OPTION_OFFSET: {
        sscanf(optarg, "%lu", &options->offset);
        break;
      }
      case OPTION_CHILDREN: {
        options->mode = MODE_CHILDREN;
        break;
      }
      case OPTION_SINGLE: {
        options->mode = MODE_SINGLE;
        break;
      }
      case OPTION_LATEX: {
        options->latex = 1;
        break;
      }
      case OPTION_FILE: {
        if(options->files_length == options->files_size) {
          options->files_size <<= 1;
          options->files = (char**)realloc(options->files, sizeof(char*) * options->files_size);
        }
        options->files[options->files_length++] = optarg;
        break;
      }
      case OPTION_CLEANUP: {
        options->cleanup = 1;
        break;
      }
      case OPTION_LIVENESS: {
        options->liveness = 1;
        break;
      }
      case OPTION_FSUBST: {
        options->fsubst = 1;
        break;
      }
      case OPTION_CHAIN: {
        options->chain = 1;
        break;
      }
      case '?':
        return 2;
    }
  }

  if(!options->files_length) return 1;

  return 0;
}

obj_t translate_single(state_t state) {
  if(setjmp(*gdsl_err_tgt(state))) return NULL;
  obj_t rreil_insns = gdsl_decode_translate_single(state, gdsl_config_default(state));
  return rreil_insns;
}

obj_t translate(state_t state) {
  if(setjmp(*gdsl_err_tgt(state))) return NULL;
  obj_t rreil_insns = gdsl_decode_translate_block(state, gdsl_config_default(state), gdsl_int_max(state));
  return rreil_insns;
}

translate_result_t translate_super(state_t state, obj_t *rreil_insns) {
  if(setjmp(*gdsl_err_tgt(state))) return NULL;
  translate_result_t rreil_insns_succs = gdsl_decode_translate_super_block(state, gdsl_config_default(state),
      gdsl_int_max(state));
  *rreil_insns = rreil_insns_succs->insns;
  return rreil_insns_succs;
}

void print_succs(state_t state, translate_result_t translated, size_t size) {
  obj_t succ_a = translated->succ_a;
  obj_t succ_b = translated->succ_b;

//	void print_succ(obj_t succ, char const *name) {
//		switch(x86_con_index(state, succ)) {
//			case __SO_SOME: {
//				obj_t succ_insns = __DECON(succ);
//				printf("Succ %s:\n", name);
//				string_t fmt = gdsl_rreil_pretty(state, succ_insns);
//				puts(fmt);
//				break;
//			}
//			case __SO_NONE: {
//				printf("Succ %s: __SO_NONE :-(\n", name);
//				break;
//			}
//		}
//	}

  string_t r = gdsl_merge_rope(state, gdsl_succ_pretty(state, succ_a, "a"));
  printf("%s\n", r);

  r = gdsl_merge_rope(state, gdsl_succ_pretty(state, succ_b, "b"));
  printf("%s\n", r);

//	print_succ(succ_a, "a");
//	print_succ(succ_b, "b");
}

struct context {
  size_t native_instructions;
  size_t stmts;
  size_t stmts_opt;
  long time_non_opt;
  long time_opt;

  size_t memory_cum;
  size_t memory_max;

  size_t blocks;
};

void print_results(struct context *context) {
  fprintf(stderr, "Statistics:\n");
  fprintf(stderr, "Number of native instructions: %zu\n", context->native_instructions);
  fprintf(stderr, "Number of blocks: %zu\n", context->blocks);
  fprintf(stderr, "Number of RReil statements without optimization: %zu\n", context->stmts);
  fprintf(stderr, "Number of RReil statements with optimization: %zu\n", context->stmts_opt);

  double reduction = 1 - (context->stmts_opt / (double)context->stmts);

  fprintf(stderr, "Reduction: %lf%%\n", 100 * reduction);

  fprintf(stderr, "Time needed for the decoding and the translation into RREIL: %lf seconds\n",
      context->time_non_opt / (double)(NANOS));
  fprintf(stderr, "Time needed for the lv analysis: %lf seconds\n", context->time_opt / (double)(NANOS));

  fprintf(stderr, "Memory accumulative: %zu bytes, memory maximal: %zu bytes\n", context->memory_cum,
      context->memory_max);
}

static char *symbol_sz(size_t value) {
  if(value < 10 * 1000) return "";
  if(value < 10 * 1000 * 1000) return "";
  return "M";
}

static size_t fit_sz(size_t value) {
  if(value < 10 * 1000) return (value + 500) / 1000;
  if(value < 10 * 1000 * 1000) return (value + 500) / 1000;
  return (value + 500 * 1000) / (1000 * 1000);
}

static char *symbol_t(double value) {
  if(value < 2 * 60) return "s";
  if(value < 2 * 60 * 60) return "m";
  return "h";
}

static double fit_t(double value) {
  if(value < 2 * 60) return value;
  if(value < 2 * 60 * 60) return value / 60;
  return value / (60 * 60);
}

void print_results_latex(char *file, struct context *single, struct context *intra, struct context *inter) {
  //netstat & 15k & 86k & 1.10s & 63k & 17.43s & 26.04\% & 53k & 39.98s & 38.51\%
  double reduction_simple = 1 - (single->stmts_opt / (double)single->stmts);
  double reduction_inter = 1 - (inter->stmts_opt / (double)inter->stmts);
  double reduction_intra = 1 - (intra->stmts_opt / (double)intra->stmts);

  double fac_non = single->stmts / (double)single->native_instructions;
  double fac_single = single->stmts_opt / (double)single->native_instructions;
  double fac_inta = intra->stmts_opt / (double)single->native_instructions;
  double fac_inter = inter->stmts_opt / (double)single->native_instructions;

  size_t file_offset = 0;
  for(size_t i = 0; file[i]; i++) {
    if(file[i] == '/') file_offset = i + 1;
  }

  printf(
      "%% program, native instructions, non-optimized statement count, decoding + translation time, non-optimized size factor, (single, intra, inter)*(statement count, time, reduction, size factor)\n");

  printf(
      "%s & %lu%s & %lu%s & %.1lf%s & %.1lf & %lu%s & %.1lf%s & %.0lf\\%% & %.1f & %lu%s & %.1lf%s & %.0lf\\%% & %.1f & %lu%s & %.1lf%s & %.0lf\\%% & %.1f \\\\\n",
      file + file_offset, fit_sz(inter->native_instructions), symbol_sz(inter->native_instructions),
      fit_sz(inter->stmts), symbol_sz(inter->stmts), fit_t(inter->time_non_opt / (double)(NANOS)),
      symbol_t(inter->time_non_opt / (double)(NANOS)), fac_non,

      fit_sz(single->stmts_opt), symbol_sz(single->stmts_opt), fit_t(single->time_opt / (double)(NANOS)),
      symbol_t(single->time_opt / (double)(NANOS)), 100 * reduction_simple, fac_single,

      fit_sz(intra->stmts_opt), symbol_sz(intra->stmts_opt), fit_t(intra->time_opt / (double)(NANOS)),
      symbol_t(intra->time_opt / (double)(1000000000)), 100 * reduction_intra, fac_inta,

      fit_sz(inter->stmts_opt), symbol_sz(inter->stmts_opt), fit_t(inter->time_opt / (double)(NANOS)),
      symbol_t(inter->time_opt / (double)(NANOS)), 100 * reduction_inter, fac_inter);
}

char analyze(char *file, char print, enum mode mode, char fsubst, char chain, char cleanup, size_t file_offset,
    size_t size_max, size_t user_offset, struct context *context) {
  size_t size = 16 * 1024 * 1024;
  char *fmt = (char*)malloc(size);

  FILE *f = fopen(file, "r");
  if(!f) {
    printf("Unable to open file.\n");
    return 1;
  }

//	fprintf(stderr, "File offset: %zu\n", file_offset);

  fprintf(stderr, "Using file offset: %zu\n", file_offset);

  fseek(f, file_offset, SEEK_SET);

  size_t buffer_size = 128;
  unsigned char *buffer = NULL;
  size_t buffer_length = 0;
  do {
    buffer_size *= 2;
    buffer = (unsigned char*)realloc(buffer, buffer_size);
    buffer_length += fread(buffer + buffer_length, 1, buffer_size - buffer_length, f);
  } while(!feof(f) && (!size_max || buffer_length < size_max));

  fclose(f);

  //printf("size_max: %lu, buffer_length: %lu\n", size_max, buffer_length);

  if(size_max && buffer_length > size_max) buffer_length = size_max;

  if(buffer_length == buffer_size) {
    buffer_size++;
    buffer = (unsigned char*)realloc(buffer, buffer_size);
  }
  buffer[buffer_length++] = 0xc3; //Last instruction should be a jump (ret) ;-).

  struct timespec start;
  struct timespec end;

//	printf("buffer_length=%zu\n", buffer_length);

  uint64_t consumed = user_offset;
//	uint64_t consumed = 228;
//	uint64_t consumed = 0;

  obj_t state = gdsl_init();

//  if(setjmp(*gdsl_err_tgt(state))) {
//    fprintf(stderr, "failed: %s\n", gdsl_get_error_message(state));
//    exit(1);
//  }

  gdsl_set_code(state, buffer, buffer_length, 0);

  context->memory_cum = 0;
  context->memory_max = 0;
  context->blocks = 0;
  context->stmts = 0;
  context->stmts_opt = 0;

  uint64_t last = 1;
  while(consumed < buffer_length) {
    if(print) printf("### Next block (@offset %lu): ###\n\n", consumed);
    context->blocks++;

    if(100*1024*last < consumed) {
      printf("%lf MB\n", ((double)consumed)/(1024*1024));
      fflush(stdout);
      fflush(stderr);
      last++;
    }

//		obj_t state = __createState(buffer + consumed, buffer_length - consumed,
//				consumed, 0);
//		gdsl_set_code(state, buffer + consumed, buffer_length - consumed, 0);
    gdsl_seek(state, consumed);

    translate_result_t translated = NULL;
    obj_t rreil_insns = NULL;
    clock_gettime(CLOCK_REALTIME, &start);
    switch(mode) {
      case MODE_SINGLE: {
        translated = rreil_insns = translate_single(state);
        break;
      }
      case MODE_DEFAULT: {
        translated = rreil_insns = translate(state);
        break;
      }
      case MODE_CHILDREN: {
        translated = translate_super(state, &rreil_insns);
        break;
      }
    }
    clock_gettime(CLOCK_REALTIME, &end);
    long diff = end.tv_sec * NANOS + end.tv_nsec - start.tv_nsec - start.tv_sec * NANOS;

    if(translated == NULL || rreil_insns == NULL) {
      printf("Translation or decoding error, ignoring block...\n");
      consumed++;
      continue;
      //break;
    }
    context->time_non_opt += diff;

    /*
     * Todo: Fix
     */
//		if(!__isNil(rreil_insns)) {
//			__fatal("TranslateBlock failed");
//			goto end;
//		}
    if(print && mode == MODE_CHILDREN) print_succs(state, translated, size);

    int_t native_instruction_count = gdsl_select_ins_count(state);
    context->native_instructions += native_instruction_count;

    //printf("%x\n", buffer[consumed]);

    if(print) {
      printf("Initial RREIL instructions:\n");
      //__pretty(__rreil_pretty__, rreil_insns, fmt, size);
      string_t fmt = gdsl_merge_rope(state, gdsl_rreil_pretty(state, rreil_insns));

      puts(fmt);
      printf("\n");
    }

    context->stmts += gdsl_rreil_stmts_count(state, rreil_insns);

//		for(size_t i = 0; fmt[i]; i++)
//			if(fmt[i] == '\n')
//				context->lines++;

    clock_gettime(CLOCK_REALTIME, &start);

    obj_t lv_initial = NULL;
    obj_t lv_after = NULL;
    obj_t rreil_result;
    switch(mode) {
      case MODE_CHILDREN: {
        if(fsubst && chain) {
          translated = gdsl_liveness_super_chainable(state, translated);
          translated = gdsl_propagate_contextful(state, 0, 1, translated);
          lv_super_result_t lv_r = gdsl_liveness_super(state, translated);
          lv_initial = lv_r->initial;
          lv_after = lv_r->after;
          rreil_result = gdsl_select_live(state);
        } else if(fsubst) {
          translated = gdsl_propagate_contextful(state, 0, 1, translated);
          lv_super_result_t lv_r = gdsl_liveness_super(state, translated);
          lv_initial = lv_r->initial;
          lv_after = lv_r->after;
          rreil_result = gdsl_select_live(state);;
        } else {
          lv_super_result_t lv_r = gdsl_liveness_super(state, translated);
          lv_initial = lv_r->initial;
          lv_after = lv_r->after;
          rreil_result = gdsl_select_live(state);
        }
        break;
      }
      default: {
        rreil_result = gdsl_liveness(state, translated);
        break;
      }
    }

    if(cleanup) {
      if(print) {
        printf("RREIL instructions before cleanup:\n");
        string_t fmt = gdsl_merge_rope(state, gdsl_rreil_pretty(state, rreil_result));
        puts(fmt);
        printf("\n");
      }

      rreil_result = gdsl_cleanup(state, rreil_result);
    }

    clock_gettime(CLOCK_REALTIME, &end);
    diff = end.tv_sec * NANOS + end.tv_nsec - start.tv_nsec - start.tv_sec * NANOS;
    context->time_opt += diff;
//		if(!__isNil(greedy_state)) {
//			__fatal("Liveness failed");
//			goto end;
//		}

    if(print && lv_initial != NULL) {
      printf("Liveness initial state:\n");
      string_t fmt = gdsl_merge_rope(state, gdsl_lv_pretty(state, lv_initial));
      puts(fmt);
      printf("\n");
    }

    if(print && lv_after != NULL) {
      printf("Liveness greedy state:\n");
      string_t fmt = gdsl_merge_rope(state, gdsl_lv_pretty(state, lv_after));
      puts(fmt);
      printf("\n");
    }

    if(print) {
      printf("RREIL instructions after LV (greedy):\n");
      string_t fmt = gdsl_merge_rope(state, gdsl_rreil_pretty(state, rreil_result));
      puts(fmt);
      printf("\n");
    }

    context->stmts_opt += gdsl_rreil_stmts_count(state, rreil_result);

//		for(size_t i = 0; fmt[i]; i++)
//			if(fmt[i] == '\n')
//				context->lines_opt++;

    //consumed += __getBlobIndex(state) - consumed;
    consumed = gdsl_get_ip(state);

    size_t residency = gdsl_heap_residency(state);
    context->memory_cum += residency;
    if(residency > context->memory_max) context->memory_max = residency;

    gdsl_reset_heap(state);

    //printf("consumed: %lu, buffer_length: %lu\n", consumed, buffer_length);
  }

  if(context->native_instructions) context->native_instructions--;

  free(buffer);
  free(fmt);

  gdsl_destroy(state);

  return 0;
}

static void file_bounds_set(struct options options, size_t *offset, size_t *size_max, char *file) {
  if(options.elf) {
    char e = elf_section_boundary_get(file, offset, size_max);
    if(e) exit(2);
  } else {
    *offset = 0;
    *size_max = 0;
  }
}

static void run(struct options options, size_t *offset, size_t *size_max, double *single_red_cum, double *intra_red_cum,
    double *inter_red_cum, size_t index, char print) {
  if(options.latex) {
    struct context inter;
    memset(&inter, 0, sizeof(inter));
    struct context intra;
    memset(&intra, 0, sizeof(intra));
    struct context single;
    memset(&single, 0, sizeof(single));

    file_bounds_set(options, offset, size_max, options.files[index]);

    //fprintf(stderr, "Size: %zu\n", *size_max);

    analyze(options.files[index], print, MODE_SINGLE, options.fsubst, options.chain, options.cleanup, *offset,
        *size_max, options.offset, &single);
    analyze(options.files[index], print, MODE_DEFAULT, options.fsubst, options.chain, options.cleanup, *offset,
        *size_max, options.offset, &intra);
    analyze(options.files[index], print, MODE_CHILDREN, options.fsubst, options.chain, options.cleanup, *offset, *size_max, options.offset, &inter);

    print_results_latex(options.files[index], &single, &intra, &inter);

    *single_red_cum += 1 - (single.stmts_opt / (double)single.stmts);
    *intra_red_cum += 1 - (intra.stmts_opt / (double)intra.stmts);
    *inter_red_cum += 1 - (inter.stmts_opt / (double)inter.stmts);
  } else {

    struct context context;
    memset(&context, 0, sizeof(context));
    file_bounds_set(options, offset, size_max, options.files[index]);
    analyze(options.files[index], print, options.mode, options.fsubst, options.chain, options.cleanup, *offset, *size_max, options.offset, &context);

    print_results(&context);
  }
}

int main(int argc, char** argv) {
//	stdout = fopen("/dev/null", "r");

  struct options options;

  if(args_parse(argc, argv, &options)) {
    printf("Usage: optimization-sweep [--children] [--offset offset] [--elf] [--cleanup] --file file\n");
    return 42;
  }

//	printf("elf=%d, offset=%lu, children=%d, file=%s, cleanup=%d\n", options.elf,
//			options.offset, options.children_consider, options.file, options.cleanup);

  const rlim_t kStackSize = 4096L * 1024L * 1024L;
  struct rlimit rl;
  int result;

  result = getrlimit(RLIMIT_STACK, &rl);
  if(result == 0) {
    if(rl.rlim_cur < kStackSize) {
      rl.rlim_cur = kStackSize;
      result = setrlimit(RLIMIT_STACK, &rl);
      if(result != 0) {
        fprintf(stderr, "setrlimit returned result = %d\n", result);
      }
    }
  }

  size_t offset;
  size_t size_max;

//	if(argc == 3) {
//		if(strcmp(argv[1], "--elf"))
//			return 1;
//		char e = elf_section_boundary_get(argv[2], &offset, &size_max);
//		if(e)
//			return 2;
//	} else if(argc != 2) {
//		printf("Usage: liveness-sweep [--elf] file\n");
//		return 1;
//	} else {
//		offset = 0;
//		size_max = 0;
//	}

//	FILE *f = fopen(argv[1 + (argc == 3)], "r");

  size_t count = 0;
  double single_red_cum = 0.0;
  double intra_red_cum = 0.0;
  double inter_red_cum = 0.0;

  if(options.files_length == 1) {
    run(options, &offset, &size_max, &single_red_cum, &intra_red_cum, &inter_red_cum, 0, 0);
    count = 1;
  } else {
    for(size_t i = 0; i < options.files_length; ++i) {
      if(!options.latex) printf("$$$$$$ File %s:\n", options.files[i]);
      run(options, &offset, &size_max, &single_red_cum, &intra_red_cum, &inter_red_cum, i, 0);
    }
    count = options.files_length;
  }

  free(options.files);

  if(count > 1) {
    printf("Average single reduction: %.3lf%%\n", 100 * single_red_cum / count);
    printf("Average intra reduction: %.3lf%%\n", 100 * intra_red_cum / count);
    printf("Average inter reduction: %.3lf%%\n", 100 * inter_red_cum / count);
  }

//	end:

  return (0);
}

