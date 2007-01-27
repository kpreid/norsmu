#!/usr/bin/env rune

# Copyright 2004-2007 Kevin Reid.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


# rune -J-XX:ThreadStackSize=10240 -cpa ~/d/lojban/lib/lojban_peg_parser.jar -cpa /Stuff/pircbot.jar -cpa /Stuff/jlib/ norsmu.e irc.freenode.net norsmu \#lojban \#jbokaj

# rune -J-XX:ThreadStackSize=10240 -cpa ~/d/lojban/lib/lojban_peg_parser.jar -cpa /Stuff/pircbot.jar -cpa /Stuff/jlib/ norsmu.e irc.freenode.net norsum \#jbokaj


pragma.syntax("0.9")

pragma.enable("accumulator")
pragma.enable("dot-props")

stderr.println("Loading")

def makeLojbanParser := <unsafe:xtc.parser.makePParser>
def makeSurgeon      := <elib:serial.makeSurgeon>
def makeNorsmuParser := <import:makeNorsmuParser>
def makeNorsmuModel := <import:makeNorsmuModel>
def makeNorsmuConverser := <import:makeNorsmuConverser>

# Set up parsing

def optParse := makeNorsmuParser(makeLojbanParser)

stderr.println("Configuring")

# --- 

def [saveName, modeArgs] := switch (interp.getArgs()) {
  match [`--save`, s] + m { [s,    m] }
  match                 m { [null, m] }
}
# --- 

stderr.println("About to make surgeon")

def [save, modelStore] := if (saveName != null) {
  def saveFile := <file>[saveName]
  def goodLoadFile := <file>[saveName + "~"]

  def surgeon := makeSurgeon()

  stderr.println("Reviving")
  def modelStore := {
    if (saveFile.exists()) {
      def data := surgeon.unserialize(saveFile.getBytes())
      #def data := e__quasiParser(saveFile.getText()).eval(safeScope)
      saveFile.renameTo(goodLoadFile, null)
      data
    } else if (goodLoadFile.exists()) {
      #e__quasiParser(saveFile.getText()).eval(safeScope)
      surgeon.unserialize(goodLoadFile.getBytes())
    } else {
      [].asMap().diverge()
    }
  }

  def save() {
    stderr.print("Serializing...")
    saveFile.setBytes(surgeon.serialize(modelStore))
    #saveFile.setText(E.toQuote(modelFlex))
    stderr.println("done")
  }

  timer.every(1000 * 60 * 60 * 72, def saveTickReactor(_) {
    stderr.print("(Timed) ")
    save()
  }).start()
  
  [save, modelStore]
} else {
  [def stubSave() {}, [].asMap().diverge()]
}

def model := makeNorsmuModel(modelStore, optParse, entropy, stderr)

# ---

#bind loadInitialSentences() {
#  stderr.println("loadInitialSentences start")
#
#  def [head, var resolver] := Ref.promise()
#  head <- ()
#
#  for `@line$\n` in <file:test_sentences.txt> {
#  
#    def [next, tailResolver] := Ref.promise()
#
#    resolver.resolve(fn {
#      next <- ()
#      escape skip {
#        def utterance := switch (line) {
#          match `#@_` { skip() }
#          match `@t -- BAD` { skip() }
#          match `@t -- GOOD` { t }
#          match _ { line }
#        }
#        stderr.println(`Init: $utterance`)
#        try {
#          def parsed := optParse(text, "")
#          if (parsed != null) {
#            model.put(parsed)
#          }
#        } catch p {
#          stderr.println(`  $p`)
#          throw(p) # goes to tracelog
#        }
#      }
#      null
#    })
#    
#    resolver := tailResolver
#    
#  }
#  
#  resolver.resolve(fn {})
#  
#  stderr.println("loadInitialSentences end")
#}

# ---

switch (modeArgs) {
  match [initServer, initNick] + initChannels {
    def makePircBot      := <unsafe:EPircBot>

    def bot

    def converser := makeNorsmuConverser(model, fn{ bot.getNick() }, stderr, optParse)
    
    def handler {
      to onPart(channel, sender, login, hostname) :void {
        converser.left([channel, sender])
      }

      to onMessage(channel, sender, login, hostname, message) :void {
        if (optParse(message, sender) =~ parsed :notNull) {
          converser(message, parsed, [channel, sender], fn m { bot.sendMessage(channel, m) }, sender)
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
        } else {
          converser."private"(optParse(message, sender), fn m { bot.sendMessage(sender, m) })
        }
      }

      match x {
        # stderr.println(`handler ignoring: $x`)
        null
      }
    }

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
    
    def converser := makeNorsmuConverser(model, fn{ "norsmu" }, stderr, optParse)

    def read :rcvr := <unsafe:org.erights.e.elib.vat.Vat>.make("headless", `stdin reader`).seed(fn {
      def stdin := <unsafe:org.erights.e.develop.exception.makePrintStreamWriter>.stdin()
      def read() {
        return stdin.readLine()
      }
    })
    
    def loop() {
      when (def line := read <- ()) -> {
        if (line != null) { 
          converser."private"(optParse(line, "-"), fn m { stdout.println(m) })
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