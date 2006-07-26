all: 

web:
	cp norsmu.e ${HOME}/Sites/2004/norsmu/

update: all
	@scp norsmu.e oasis.slimy.com:bin/norsmu.e
	@scp norsmu-start-slimy oasis.slimy.com:bin/norsmu-start

# FIXME: norsmu-start, norsmu-ephem.e not available locally

# future work: web page with source update
#              automatic restarting upon update target
#              rsync or similar for checking

# (cd jlib; rm lojban_peg_parser.jar; wget http://www.digitalkingdom.org/~rlpowell/hobbies/lojban/grammar/rats/lojban_peg_parser.jar)

# killall java; (cd jlib; rm lojban_peg_parser.jar; wget http://www.digitalkingdom.org/~rlpowell/hobbies/lojban/grammar/rats/lojban_peg_parser.jar); norsmu-start