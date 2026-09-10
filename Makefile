#
# Makefile - ADAS ECU Supervisor POC
#
# Targets:
#   make                 Build supervisor and ECU process
#   make run             Build and run supervisor
#   make test-syscall    Run syscall-level tests
#   make test-cunit      Run CUnit tests
#   make test             Run all tests
#
#   make memcheck        Valgrind memory + FD checking
#   make helgrind        Valgrind thread checking
#   make massif          Valgrind memory profiling
#   make cachegrind      Valgrind cache profiling
#   make cppcheck        Static analysis using Cppcheck
#   make misra-check     MISRA-oriented source checks
#   make analysis        Run Cppcheck + Valgrind checks
#
#   make clean           Remove build output and logs
#

CC       := gcc

# Normal compilation flags
CFLAGS   := -Wall -Wextra -g -Iinclude

LDFLAGS  :=

SRC_DIR  := src
INC_DIR  := include
OBJ_DIR  := obj
BIN_DIR  := bin
TEST_DIR := tests
LOG_DIR  := logs
REPORT_DIR := reports

# ------------------------------------------------------------
# Source files
# ------------------------------------------------------------

SUPERVISOR_SRCS := main.c supervisor.c logger.c config_parser.c signal_handler.c

SUPERVISOR_OBJS := $(patsubst %.c,$(OBJ_DIR)/%.o,$(SUPERVISOR_SRCS))


# ------------------------------------------------------------
# Default target
# ------------------------------------------------------------

.PHONY: all run clean test test-syscall test-cunit \
        memcheck helgrind massif cachegrind cppcheck \
        misra-check analysis dirs

all: dirs $(BIN_DIR)/supervisor $(BIN_DIR)/ecu_process


# ------------------------------------------------------------
# Create required directories
# ------------------------------------------------------------

dirs:
	@mkdir -p $(OBJ_DIR)
	@mkdir -p $(OBJ_DIR)/test
	@mkdir -p $(BIN_DIR)
	@mkdir -p $(BIN_DIR)/tests/syscall
	@mkdir -p $(BIN_DIR)/tests/cunit
	@mkdir -p $(LOG_DIR)
	@mkdir -p $(REPORT_DIR)


# ------------------------------------------------------------
# Compile source files
# ------------------------------------------------------------

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c | dirs
	$(CC) $(CFLAGS) -c $< -o $@


# ------------------------------------------------------------
# Build Supervisor
# ------------------------------------------------------------

$(BIN_DIR)/supervisor: $(SUPERVISOR_OBJS) | dirs
	$(CC) $(CFLAGS) $^ -o $@ $(LDFLAGS)


# ------------------------------------------------------------
# Build simulated ECU process
# ------------------------------------------------------------

$(BIN_DIR)/ecu_process: $(OBJ_DIR)/ecu_process.o | dirs
	$(CC) $(CFLAGS) $^ -o $@ $(LDFLAGS)


# ------------------------------------------------------------
# Run application
# ------------------------------------------------------------

run: all
	./$(BIN_DIR)/supervisor config/ecu_config.conf


# ============================================================
# SYSCALL TESTS
# ============================================================

SYSCALL_TESTS := test_main_syscall test_supervisor_syscall test_logger_syscall \
                 test_config_parser_syscall test_signal_handler_syscall \
                 test_ecu_process_syscall


$(BIN_DIR)/tests/syscall/%: $(TEST_DIR)/syscall/%.c | dirs
	$(CC) $(CFLAGS) $< -o $@


test-syscall: all $(addprefix $(BIN_DIR)/tests/syscall/,$(SYSCALL_TESTS))
	@echo ""
	@echo "###### RUNNING SYSCALL TESTS ######"
	@echo ""

	@failed=0; \
	for t in $(SYSCALL_TESTS); do \
		echo "--- $$t ---"; \
		./$(BIN_DIR)/tests/syscall/$$t; \
		if [ $$? -ne 0 ]; then failed=1; fi; \
		echo ""; \
	done; \
	exit $$failed


# ============================================================
# CUNIT TESTS
# ============================================================

CUNIT_LDFLAGS := -lcunit


$(BIN_DIR)/tests/cunit/test_supervisor_cunit: \
	$(TEST_DIR)/cunit/test_supervisor_cunit.c \
	$(OBJ_DIR)/supervisor.o \
	$(OBJ_DIR)/logger.o \
	$(OBJ_DIR)/config_parser.o \
	$(OBJ_DIR)/signal_handler.o | dirs

	$(CC) $(CFLAGS) $^ -o $@ $(CUNIT_LDFLAGS)


$(BIN_DIR)/tests/cunit/test_logger_cunit: \
	$(TEST_DIR)/cunit/test_logger_cunit.c \
	$(OBJ_DIR)/logger.o | dirs

	$(CC) $(CFLAGS) $^ -o $@ $(CUNIT_LDFLAGS)


$(BIN_DIR)/tests/cunit/test_config_parser_cunit: \
	$(TEST_DIR)/cunit/test_config_parser_cunit.c \
	$(OBJ_DIR)/config_parser.o \
	$(OBJ_DIR)/supervisor.o \
	$(OBJ_DIR)/logger.o \
	$(OBJ_DIR)/signal_handler.o | dirs

	$(CC) $(CFLAGS) $^ -o $@ $(CUNIT_LDFLAGS)


$(BIN_DIR)/tests/cunit/test_signal_handler_cunit: \
	$(TEST_DIR)/cunit/test_signal_handler_cunit.c \
	$(OBJ_DIR)/signal_handler.o | dirs

	$(CC) $(CFLAGS) $^ -o $@ $(CUNIT_LDFLAGS)


# ecu_process.c static functions are tested by including
# ecu_process.c directly in the test.
#
# ECU_PROCESS_TESTING disables its main().

$(BIN_DIR)/tests/cunit/test_ecu_process_cunit: \
	$(TEST_DIR)/cunit/test_ecu_process_cunit.c | dirs

	$(CC) $(CFLAGS) $< -o $@ $(CUNIT_LDFLAGS)


# main.c's main() is disabled using MAIN_TESTING.

$(OBJ_DIR)/test/main_testable.o: $(SRC_DIR)/main.c | dirs
	$(CC) $(CFLAGS) -DMAIN_TESTING -c $< -o $@


$(BIN_DIR)/tests/cunit/test_main_cunit: \
	$(TEST_DIR)/cunit/test_main_cunit.c \
	$(OBJ_DIR)/test/main_testable.o | dirs

	$(CC) $(CFLAGS) $^ -o $@ $(CUNIT_LDFLAGS)


CUNIT_TESTS := test_main_cunit test_supervisor_cunit test_logger_cunit \
               test_config_parser_cunit test_signal_handler_cunit \
               test_ecu_process_cunit


test-cunit: $(addprefix $(BIN_DIR)/tests/cunit/,$(CUNIT_TESTS))
	@echo ""
	@echo "###### RUNNING CUNIT TESTS ######"
	@echo ""

	@failed=0; \
	for t in $(CUNIT_TESTS); do \
		echo "--- $$t ---"; \
		./$(BIN_DIR)/tests/cunit/$$t; \
		if [ $$? -ne 0 ]; then failed=1; fi; \
		echo ""; \
	done; \
	exit $$failed


# ------------------------------------------------------------
# Run all tests
# ------------------------------------------------------------

test: test-syscall test-cunit


# ============================================================
# VALGRIND
# ============================================================

VALGRIND := valgrind

VALGRIND_MEMCHECK_FLAGS := \
	--leak-check=full \
	--show-leak-kinds=all \
	--track-fds=yes \
	--trace-children=yes


# ------------------------------------------------------------
# Valgrind Memory Check
#
# Checks:
#   - Memory leaks
#   - Invalid memory access
#   - Invalid free
#   - File descriptor leaks
#   - Child processes created using fork/exec
# ------------------------------------------------------------

memcheck: all
	@mkdir -p $(REPORT_DIR)

	$(VALGRIND) $(VALGRIND_MEMCHECK_FLAGS) \
		--log-file=$(REPORT_DIR)/valgrind_memcheck.txt \
		./$(BIN_DIR)/supervisor config/ecu_config.conf


# ------------------------------------------------------------
# Valgrind Helgrind
#
# Useful if multithreading is added later.
# Current supervisor is primarily single-threaded.
# ------------------------------------------------------------

helgrind: all
	@mkdir -p $(REPORT_DIR)

	$(VALGRIND) --tool=helgrind \
		--log-file=$(REPORT_DIR)/valgrind_helgrind.txt \
		./$(BIN_DIR)/supervisor config/ecu_config.conf


# ------------------------------------------------------------
# Valgrind Massif
#
# Tracks heap memory usage over time.
# ------------------------------------------------------------

massif: all
	@mkdir -p $(REPORT_DIR)

	$(VALGRIND) --tool=massif \
		--log-file=$(REPORT_DIR)/valgrind_massif.txt \
		./$(BIN_DIR)/supervisor config/ecu_config.conf

	@echo ""
	@echo "Massif output:"
	@ls -1 massif.out.* 2>/dev/null || true


# ------------------------------------------------------------
# Valgrind Cachegrind
#
# Used for CPU/cache performance analysis.
# ------------------------------------------------------------

cachegrind: all
	@mkdir -p $(REPORT_DIR)

	$(VALGRIND) --tool=cachegrind \
		--log-file=$(REPORT_DIR)/valgrind_cachegrind.txt \
		./$(BIN_DIR)/supervisor config/ecu_config.conf


# ============================================================
# CPPCHECK
# ============================================================

cppcheck:
	@mkdir -p $(REPORT_DIR)

	cppcheck \
		--enable=all \
		--inconclusive \
		--std=c11 \
		-I$(INC_DIR) \
		$(SRC_DIR) \
		2> $(REPORT_DIR)/cppcheck.txt

	@echo ""
	@echo "Cppcheck report generated:"
	@echo "$(REPORT_DIR)/cppcheck.txt"


# ============================================================
# MISRA-ORIENTED CHECKS
# ============================================================

misra-check:
	@mkdir -p $(REPORT_DIR)

	@echo "========================================="
	@echo " MISRA-ORIENTED SOURCE CHECKS"
	@echo "========================================="

	@echo ""
	@echo "[1] Compiler warnings"
	@echo "-----------------------------------------"

	$(CC) \
		-Wall \
		-Wextra \
		-Wpedantic \
		-Wconversion \
		-Wshadow \
		-Wformat=2 \
		-I$(INC_DIR) \
		-fsyntax-only \
		$(SRC_DIR)/*.c \
		2>&1 | tee $(REPORT_DIR)/compiler_checks.txt

	@echo ""
	@echo "[2] Cppcheck"
	@echo "-----------------------------------------"

	cppcheck \
		--enable=warning,style,performance,portability \
		--std=c11 \
		-I$(INC_DIR) \
		$(SRC_DIR) \
		2>&1 | tee $(REPORT_DIR)/misra_cppcheck.txt

	@echo ""
	@echo "MISRA-oriented reports generated in:"
	@echo "$(REPORT_DIR)/"


# ============================================================
# COMPLETE ANALYSIS
# ============================================================

analysis: all
	@echo ""
	@echo "========================================="
	@echo " ADAS SUPERVISOR CODE ANALYSIS"
	@echo "========================================="

	@echo ""
	@echo "1. Running Cppcheck..."
	$(MAKE) cppcheck

	@echo ""
	@echo "2. Running Valgrind Memcheck..."
	$(MAKE) memcheck

	@echo ""
	@echo "3. Running MISRA-oriented checks..."
	$(MAKE) misra-check

	@echo ""
	@echo "========================================="
	@echo " ANALYSIS COMPLETED"
	@echo "========================================="

	@echo ""
	@echo "Reports are available in:"
	@echo "reports/"


# ============================================================
# CLEAN
# ============================================================

clean:
	rm -rf $(OBJ_DIR)
	rm -rf $(BIN_DIR)
	rm -rf $(REPORT_DIR)
	rm -f $(LOG_DIR)/*.log
	rm -f massif.out.*
	rm -f cachegrind.out.*