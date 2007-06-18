" This file supplies automatic tag regeneration when saving files
" There's a problem with ctags when run with -a (append)
" ctags doesn't remove entries for the supplied source file that no longer exist
" so this script (implemented in python) finds a tags file for the file vim has
" just saved, removes all entries for that source file and *then* runs ctags -a

if has("python")

python << EEOOFF
import os
import string
import os.path
import fileinput
import sys
import vim

def echo(str):
   str=str.replace('\\', '\\\\')
   str=str.replace('"', "'")
   vim.command("redraw | echo \"%s\"" % str)

class AutoTag:
   def __init__(self, excludesuffix="", ctags_cmd="ctags", verbose=0):
      self.tags = {}
      self.excludesuffix = [ "." + s for s in excludesuffix.split(".") ]
      verbose = long(verbose)
      if verbose > 0:
         self.verbose = verbose
      else:
         self.verbose = 0
      self.sep_used_by_ctags = '/'
      self.cwd = os.getcwd()
      self.ctags_cmd = ctags_cmd
      self.count = 0

   def findTagFile(self, source):
      ( drive, file ) = os.path.splitdrive(source)
      while file:
         file = os.path.dirname(file)
         tagsFile = os.path.join(drive, file, "tags")
         self.diag(2, "does %s exist?", tagsFile)
         if os.path.isfile(tagsFile):
            self.diag(2, "Found tags file %s", tagsFile)
            return tagsFile
         elif not file or file == os.sep or file == "//" or file == "\\\\":
            self.diag(2, "exhausted search for tag file for %s", source)
            return None
         self.diag(2, "Nope. :-| %s does NOT exist", tagsFile)
      return None

   def addSource(self, source):
      if not source:
         return
      if os.path.splitext(source)[1] in self.excludesuffix:
         self.diag(1, "Ignoring excluded file " + source)
         return
      tagsFile = self.findTagFile(source)
      if tagsFile:
         self.diag(2, "if tagsFile:")
         relativeSource = source[len(os.path.dirname(tagsFile)):]
         self.diag(2, "relativeSource = source[len(os.path.dirname(tagsFile)):]")
         if relativeSource[0] == os.sep:
            self.diag(2, "if relativeSource[0] == os.sep:")
            relativeSource = relativeSource[1:]
            self.diag(2, "relativeSource = relativeSource[1:]")
         if os.sep != self.sep_used_by_ctags:
            self.diag(2, "if os.sep != self.sep_used_by_ctags:")
            relativeSource = string.replace(relativeSource, os.sep, self.sep_used_by_ctags)
            self.diag(2, "relativeSource = string.replace(relativeSource, os.sep, self.sep_used_by_ctags)")
         if self.tags.has_key(tagsFile):
            self.diag(2, "if self.tags.has_key(tagsFile):")
            self.tags[tagsFile].append(relativeSource)
            self.diag(2, "self.tags[tagsFile].append(relativeSource)")
         else:
            self.diag(2, "else:")
            self.tags[tagsFile] = [ relativeSource ]
            self.diag(2, "self.tags[tagsFile] = [ relativeSource ]")

   def stripTags(self, tagsFile, sources):
      self.diag(1, "Removing tags for %s from tags file %s", (sources, tagsFile))
      backup = ".SAFE"
      for line in fileinput.input(files=tagsFile, inplace=True, backup=backup):
         if line[-1:] == '\n':
            line = line[:-1]
         if line[-1:] == '\r':
            line = line[:-1]
         if line[0] == "!":
            print line
         else:
            fields = string.split(line, "\t")
            if len(fields) > 3:
               found = False
               for source in sources:
                  if fields[1] == source:
                     found = True
                     break
               if not found:
                  print line
            else:
               print line
      os.unlink(tagsFile + backup)

   def rebuildTagFiles(self):
      for tagsFile in self.tags.keys():
         tagsDir = os.path.dirname(tagsFile)
         sources = self.tags[tagsFile]
         os.chdir(tagsDir)
         self.stripTags(tagsFile, sources)
         cmd = "%s -a " % self.ctags_cmd
         for source in sources:
            if os.path.isfile(source):
               cmd += " '%s'" % source
         self.diag(1, "%s: %s", (tagsDir, cmd))
         (ch_in, ch_out) = os.popen2(cmd)
         for line in ch_out:
            pass
      os.chdir(self.cwd)

   def diag(self, level, msg, args = None):
      if msg and args:
         msg = msg % args
      if level <= self.verbose:
         echo(msg)
EEOOFF

function! AutoTag()
python << EEOOFF
at = AutoTag(vim.eval("g:autotagExcludeSuffixes"), vim.eval("g:autotagCtagsCmd"), long(vim.eval("g:autotagVerbosityLevel")))
at.addSource(vim.eval("expand(\"%:p\")"))
at.rebuildTagFiles()
EEOOFF
endfunction

if !exists("g:autotagVerbosityLevel")
   let g:autotagVerbosityLevel=0
endif
if !exists("g:autotagExcludeSuffixes")
   let g:autotagExcludeSuffixes="tml.xml"
endif
if !exists("g:autotagCtagsCmd")
   let g:autotagCtagsCmd="ctags"
endif
if !exists("g:autotag_autocmd_set")
   let g:autotag_autocmd_set=1
   autocmd BufWritePost,FileWritePost * call AutoTag ()
endif

endif " has("python")

" vim:sw=3:ts=3
