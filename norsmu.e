#!/usr/bin/env rune

# Copyright 2004 Kevin Reid.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


# rune -J-XX:ThreadStackSize=10240 -cpa ~/d/lojban/lib/lojban_peg_parser.jar -cpa /Stuff/pircbot.jar -cpa /Stuff/jlib/ norsmu.e irc.freenode.net norsmu \#lojban \#jbokaj

# rune -J-XX:ThreadStackSize=10240 -cpa ~/d/lojban/lib/lojban_peg_parser.jar -cpa /Stuff/pircbot.jar -cpa /Stuff/jlib/ norsmu.e irc.freenode.net norsum \#jbokaj


pragma.enable("easy-return")
pragma.disable("explicit-result-guard")

pragma.enable("accumulator")
pragma.enable("dot-props")

stderr.println("Loading")

def makeLojbanParser := <unsafe:xtc.parser.PParser>
def makeStringReader := <import:java.io.StringReader>
def makeTextWriter   := <import:org.erights.e.elib.oldeio.TextWriter>
def termParser       := <import:org.quasiliteral.term.TermParser>
def makeTerm         := <import:org.quasiliteral.term.Term>
def Term             := <type:org.quasiliteral.term.Term>
def makeSurgeon      := <elib:serial.makeSurgeon>

# Set up parsing

def filterTerminals(term :Term) {
  if (term.getTag().getTagName() =~ `@{kind}Clause` &&
        term =~ term`${`${kind}Clause`}(
                  ${`${kind}Pre`}(
                    $kind(@_(@_(@{text :String})))))`) {
    return term`$kind(.String.$text)`
  } else if (term.getTag().getTagName() =~ `@{kind}Clause` &&
        term =~ term`${`${kind}Clause`}(
                  ${`${kind}Pre`}(
                    $kind(@_(@_(@{text :String})))),
                  ${`${kind}Post`}(
                    @postElems*))`) {
    return term`$kind(.String.$text, $postElems*)`
  } else {
    return makeTerm(term.getTag(), term.getOptData(), term.getOptSpan(), 
      accum [] for sub in term.getArgs() {
        _.with(filterTerminals(sub))
      })
  }
}

def parserOutputToTerm(ptext) :any {
  return termParser("text(" + ptext + ")")
}

def optParse(text :String, source :String) :nullOk[Term] {
  def rawParse(blanks) {
    makeLojbanParser::parserParens := false
    makeLojbanParser::blanks := false
    makeLojbanParser::pretty := false
    makeLojbanParser::text := false
    makeLojbanParser::terml := false
    makeLojbanParser::verbose := true
    makeLojbanParser::latex := false
    def demorph := makeLojbanParser(makeStringReader(text), source + " morphology").pmorphology(0)
    
    if (!demorph.hasValue()) {
      stderr.println("morphology stage admitted failure")
      return ""
    }

    var dmfinal := demorph.semanticValue().replaceAll("Morph=(", "=(")

    #if (dmfinal =~ ` text=( @s ) `) {
    #  dmfinal := s
    #}

    makeLojbanParser::blanks := blanks
    makeLojbanParser::terml := true
    makeLojbanParser::verbose := false
    
    return makeLojbanParser.finalMakeString(makeLojbanParser(makeStringReader(dmfinal), source + " grammar").ptext(0).semanticValue())
  }

  if (rawParse(true).indexOf("EOF") == -1) {
    return null
  }

  return filterTerminals(parserOutputToTerm(rawParse(false)))
}

stderr.println("Configuring")

# !!! global state
makeLojbanParser.setTerml(true)
makeLojbanParser.setWhitespace(false)
makeLojbanParser.setBlanks(false)

# --- 

def loadInitialSentences

def [saveName] + modeArgs := interp.getArgs()

# --- 

stderr.println("About to make surgeon")

def saveFile := <file: saveName>
def goodLoadFile := <file: saveName + "~">

def surgeon := makeSurgeon()

stderr.println("Reviving")
def modelFlex := {
  if (saveFile.exists()) {
    def data := surgeon.unserialize(saveFile.getBytes())
    #def data := e__quasiParser(saveFile.getText()).eval(safeScope)
    saveFile.renameTo(goodLoadFile, null)
    data
  } else if (goodLoadFile.exists()) {
    #e__quasiParser(saveFile.getText()).eval(safeScope)
    surgeon.unserialize(goodLoadFile.getBytes())
  } else {
    #loadInitialSentences <- ()
    [].asMap().diverge()
  }
}

def save() {
  stderr.print("Serializing...")
  saveFile.setBytes(surgeon.serialize(modelFlex))
  #saveFile.setText(E.toQuote(modelFlex))
  stderr.println("done")
}

timer.every(1000 * 60 * 60 * 72, def saveTickReactor(_) {
  stderr.print("(Timed) ")
  save()
}).start()

#def save() {}

# ---

def termSearch__quasiParser {
  to matchMaker(s) :any {
    def submm := term__quasiParser.matchMaker(s)
    def mm {
      to matchBind(args, specimen, optEjector) :any {
        def failure := escape fail {
          return submm.matchBind(args, specimen, fail)
        } 
        for sub in specimen.getArgs() {
          return mm.matchBind(args, sub, __continue)
        }
        throw.eject(optEjector, `$submm doesn't match anywhere in $specimen`)
      }
    }
    return mm
  }
}

# ---

def addToModel(text, depth) {
  var reject := false
  
  def args := accum [] for a in text.getArgs() { _.with(
    if (text =~ term`CMENE`) {
      reject := true
    } else if (a =~ term`.String.`) {
      a.getOptData()
    } else {
      addToModel(a, depth + 1)
      a.getTag()
    }
  ) }

  if (reject) {
    return
  }
  
  for vary in (-2..2) + depth {  
    def production := [text.getTag(), vary]

    def prodModelFlex := modelFlex.fetch(production, thunk{modelFlex[production] := [].asMap().diverge()})
    
    prodModelFlex[args] := prodModelFlex.fetch(args, thunk{0}) + 1
  }
}

def makeSentence(depth, maxDepth, ptag) {
  if (depth > maxDepth) {
    return null
  }

  def depti := depth + 1
  #stderr.println("| " + " " * depth + `$ptag`)
  switch (ptag) {
    match x :String { 
      return x + " " 
    }
    match _ {
      def production := [ptag, depth]
      def choiceFreq := modelFlex.fetch(production, thunk{ return E.toString(production) + " " })

      def total := accum 0 for v in choiceFreq { _ + v }
      
      def pickedFIndex := entropy.nextInt(total)
      
      var runningOffset := 0
      def pickedSyms :notNull := for syms => freq in choiceFreq { 
        runningOffset += freq
        if (pickedFIndex < runningOffset) {
          break syms
        }
      }
      
      #for syms in choices.sort(def randomCompFunc(_, _) {return entropy.nextInt(3) - 1}) {
        return accum "" for sym in pickedSyms { _ + if (makeSentence(depti, maxDepth, sym) =~ sent :notNull) { sent } else { 
          continue
          #return null
        } }
      #}
      
      return null
    }
  }
}

def makeGoodSentence() {
  stderr.println("entering makeGoodSentence")
  var sentence := null
  var tries := 0
  while ((sentence == null || sentence == "" || optParse(sentence, "loopback") == null) && tries < 10) {
    stderr.print("-")
    sentence := makeSentence(1, 30, term`text`.getTag())
    tries += 1
  }
  stderr.println("> " + sentence)
  return sentence
}

def addUtterance(text, mayPrint) {
  def parsed := optParse(text, "")
  if (parsed != null) {
    if (mayPrint) {
      stderr.println(parsed.asText())
    }
    addToModel(parsed, 1)
  }
}

# --- 

bind loadInitialSentences() {
  stderr.println("loadInitialSentences start")

  def [head, var resolver] := Ref.promise()
  head <- ()

  for `@line$\n` in <file:test_sentences.txt> {
  
    def [next, tailResolver] := Ref.promise()

    resolver.resolve(thunk {
      next <- ()
      escape skip {
        def utterance := switch (line) {
          match `#@_` { skip() }
          match `@t -- BAD` { skip() }
          match `@t -- GOOD` { t }
          match _ { line }
        }
        stderr.println(`Init: $utterance`)
        try {
          addUtterance(utterance, false)
        } catch p {
          stderr.println(`  $p`)
          throw(p) # goes to tracelog
        }
      }
      null
    })
    
    resolver := tailResolver
    
  }
  
  resolver.resolve(thunk {})
  
  stderr.println("loadInitialSentences end")
}

# ---

if (false) {
  for k => v in modelFlex {
    stderr.println(`$k =>`)
    for vv in v {
      stderr.println(`        $vv`)
    }
  }
}

#interp.exitAtTop()

# ---

var addressingMe := [].asSet()

# ---


def bot

def isMyName(terms) {
  return switch (terms) {
    match [term`selbri(selbri1(selbri2(selbri3(selbri4(selbri5(selbri6(tanruUnit(tanruUnit1(tanruUnit2(BRIVLA(.String.${bot.getNick()}, @_*)))))))))))`] { true }
    match [term`sumti(sumti1(sumti2(sumti3(sumti4(sumti5(sumti6(LAClause(LAPre(LA(CMAVO(LA( "la" ))))), sumtiTail(sumtiTail1(@{selbri ? isMyName([selbri])})))))))))`] { true }
    match _ { false }
  }
}

def handler {
  to onPart(channel, sender, login, hostname) :void {
    addressingMe without= [channel, sender]
  }

  to onMessage(channel, sender, login, hostname, message) :void {
    def context := [channel, sender]
    
    def optParsed := optParse(message, sender)
    
    var unknownMention := false
    
    if (optParsed =~ parsed :notNull) {
      # XXX refactor - e.g. we're duplicating some of addUtterance, and have lots of duplicate code in matching selbri
      stderr.println(parsed.asText())
      addToModel(parsed, 1)
      
      if (parsed =~ termSearch`free(vocative(COI(@{s :String ? ["ju'i", "re'i"].contains(s)}), NAI("nai"), DOI?), @{nameTerms ? isMyName(nameTerms)}*, DOhU?)`) {
        stderr.println(`addr- $context: ju'inai`)
        if (addressingMe.contains(context)) {
          bot.sendMessage(channel, "fe'o " + sender)
          addressingMe without= context
        }
      } else if (parsed =~ termSearch`free(vocative(COI(@{s :String ? ["fe'o", "co'o"].contains(s)}), DOI?), @{nameTerms ? isMyName(nameTerms)}*, DOhU?)`) {
        stderr.println(`addr- $context: fe'o`)
        if (addressingMe.contains(context)) {
          bot.sendMessage(channel, "fe'o " + sender)
          addressingMe without= context
        }
      } else if (parsed =~ termSearch`free(vocative(COI?, NAI?, DOI?), @{nameTerms ? isMyName(nameTerms)}*, DOhU?)`) {
        stderr.println(`addr+ $context: naming us`)
        if (!addressingMe.contains(context)) {
          bot <- sendMessage(channel, "re'i " + sender) # cheap defer till after regular msg
          addressingMe with= context
        }
      } else if (parsed =~ termSearch`free(vocative(COI(@{s ? (s != "mi'e")})?, DOI?), @_+, DOhU?)`) {
        stderr.println(`addr- $context: doi da poi na du mi`)
        # vocative with some name/sumti, but not us (earlier cases would catch it)
        addressingMe without= context
      } else {
        unknownMention := message.indexOf(bot.getNick()) != -1
      }
    }
    
    if ((unknownMention || addressingMe.contains(context)) && optParsed != null) {
      stderr.println("handle: responding")
      bot.sendMessage(channel, makeGoodSentence())
      stderr.println("handle: done responding")
    } else {
      stderr.println(`handle: not responding (nick=${bot.getNick()} parsed=${optParsed != null})`)
    }
  }

  to onPrivateMessage(sender, login, hostname, message) :void {
    if (message == "save") {
      save()
    } else if (message == "quit") {
      bot.disconnect()
      bot.dispose()
      save()
      interp.exitAtTop()
    #} else if (message == "initload") {
    #  loadInitialSentences()
    } else {
      def optParsed := optParse(message, sender)
      
      if (optParsed =~ parsed :notNull) {
        # XXX refactor - e.g. we're duplicating some of addUtterance.
        stderr.println(parsed.asText())
        addToModel(parsed, 1)
        bot.sendMessage(sender, makeGoodSentence())
      } else {
        bot.sendMessage(sender, "di'u na gendra")
      }
      
      #addUtterance(message, true)
      #bot.sendMessage(sender, makeGoodSentence())
    }
  }

  match x {
    # stderr.println(`handler ignoring: $x`)
    null
  }
}

switch (modeArgs) {
  match [initServer, initNick] + initChannels {
    def makePircBot      := <unsafe:EPircBot>

    bind bot := makePircBot(handler, true, false)
    
    bot.setConnectName(initNick)
    bot.connect(initServer)
    for ch in initChannels {
      bot.joinChannel(ch)
    }
    
    interp.blockAtTop()
    #bot
  }
  match [`-`] {
    
    bind bot {
      to dispose() {}
      to disconnect() {
        interp.continueAtTop()
      }
      to sendMessage(who, what :String) {
        stdout.println(what)
      }
    }
    
    def read :rcvr := <unsafe:org.erights.e.elib.vat.Vat>.make("headless", `stdin reader`).seed(thunk {
      def stdin := <unsafe:org.erights.e.develop.exception.makePrintStreamWriter>.stdin()
      def read() {
        return stdin.readLine()
      }
    })
    
    def loop() {
      when (read <- ()) -> got(line) {
        if (line != null) { 
          handler.onPrivateMessage("cusku", null, null, line)
          loop()
        } else {
          interp.continueAtTop()
        } 
      } catch p {
        interp.exitAtTop(p)
      }
    }
    loop()
    interp.blockAtTop()
  }
}

save() # will happen after the continueAtTop