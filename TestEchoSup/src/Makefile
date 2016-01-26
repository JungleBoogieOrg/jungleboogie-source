EBIN = ../ebin
INCLUDE = ../include
EFLAGS = -I $(INCLUDE) -Dlog_trace -Dlog_warn -Dlog_debug -Dlog_info
# EFLAGS = -I $(INCLUDE) -Dlog_warn -Dlog_info
TARGETS = $(EBIN)/echo_sup.beam $(EBIN)/echo_main.beam $(EBIN)/echo_writer.beam $(EBIN)/echo_reader.beam $(EBIN)/echo_conn.beam

$(EBIN)/%.beam: %.erl
	erlc  -W -b beam -o $(EBIN) $(EFLAGS) $(WAIT) $<

all: $(TARGETS)

clean:
	rm $(TARGETS)
