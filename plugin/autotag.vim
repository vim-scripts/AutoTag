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

class AutoTag:
   def __init__(self, excludesuffix="", verbose=False):
      self.tags = {}
      self.excludesuffix = [ "." + s for s in excludesuffix.split(".") ]
      self.verbose = verbose
      self.sep_used_by_ctags = '/'
      self.cwd = os.getcwd()

   def findTagFile(self, source):
      ( drive, file ) = os.path.splitdrive(source)
      while file:
         file = os.path.dirname(file)
         tagsFile = os.path.join(drive, file, "tags")
        #self.diag("does %s exist?", tagsFile)
         if os.path.isfile(tagsFile):
           #self.diag("Found tags file %s", tagsFile)
            return tagsFile
         elif not file or file == os.sep or file == "//" or file == "\\\\":
           #self.diag("exhausted search for tag file for %s", source)
            return None
        #self.diag("Nope. :-| %s does NOT exist", tagsFile)
      return None

   def addSource(self, source):
      if not source:
         return
      if os.path.splitext(source)[1] in self.excludesuffix:
         self.diag("Ignoring excluded file " + source)
         return
      tagsFile = self.findTagFile(source)
      if tagsFile:
         #self.diag("if tagsFile:")
         relativeSource = source[len(os.path.dirname(tagsFile)):]
         #self.diag("relativeSource = source[len(os.path.dirname(tagsFile)):]")
         if relativeSource[0] == os.sep:
            #self.diag("if relativeSource[0] == os.sep:")
            relativeSource = relativeSource[1:]
            #self.diag("relativeSource = relativeSource[1:]")
         if os.sep != self.sep_used_by_ctags:
            #self.diag("if os.sep != self.sep_used_by_ctags:")
            relativeSource = string.replace(relativeSource, os.sep, self.sep_used_by_ctags)
            #self.diag("relativeSource = string.replace(relativeSource, os.sep, self.sep_used_by_ctags)")
         if self.tags.has_key(tagsFile):
            #self.diag("if self.tags.has_key(tagsFile):")
            self.tags[tagsFile].append(relativeSource)
            #self.diag("self.tags[tagsFile].append(relativeSource)")
         else:
            #self.diag("else:")
            self.tags[tagsFile] = [ relativeSource ]
            #self.diag("self.tags[tagsFile] = [ relativeSource ]")

   def stripTags(self, tagsFile, sources):
      self.diag("Removing tags for %s from tags file %s", (sources, tagsFile))
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
         cmd = "ctags -a"
         for source in sources:
            if os.path.isfile(source):
               cmd += " '%s'" % source
         self.diag("%s: %s", (tagsDir, cmd))
         (ch_in, ch_out) = os.popen2(cmd)
         for line in ch_out:
            pass
      os.chdir(self.cwd)

   def diag(self, msg, args = None):
      if self.verbose and msg:
         if args:
            msg = msg % args
         vim.command("redraw | echo \"%s\"" % msg.replace('\\', '/'))
EEOOFF

function! AutoTag()
python << EEOOFF
at = AutoTag(vim.eval("g:autotagExcludeSuffixes"), True)
at.addSource(vim.eval("expand(\"%:p\")"))
at.rebuildTagFiles()
EEOOFF
endfunction

if !exists("g:autotag_autocmd_set")
   let g:autotag_autocmd_set = 1
   if !exists("g:autotagExcludeSuffixes")
      let g:autotagExcludeSuffixes="tml.xml"
   endif
   autocmd BufWritePost,FileWritePost * call AutoTag ()
endif

endif " has("python")

" vim:sw=3:ts=3
