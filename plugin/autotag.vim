" This file supplies automatic tag regeneration when saving files
" There's a problem with ctags when run with -a (append)
" ctags doesn't remove entries for the supplied source file that no longer exist
" so this script (implemented in python) finds a tags file for the file vim has
" just saved, removes all entries for that source file and *then* runs ctags -a

if has("python")

function! AutoTag()
python << EEOOFF
import os
import string
import os.path
import fileinput
import sys
import vim

class AutoTag:
   def __init__(self, verbose=False, convert_backslashes = True):
      self.tags = {}
      self.verbose = verbose
      self.convert_backslashes = convert_backslashes

   def findTagFile(self, source):
      ( drive, file ) = os.path.splitdrive(source)
      while file:
         file = os.path.dirname(file)
         tagsFile = os.path.join(drive, file, "tags")
        #self.diag("does %s exist?", tagsFile)
         if os.path.isfile(tagsFile):
           #self.diag("%s DOES exist!", tagsFile)
            return tagsFile
         elif file == '\\' or file == '':
           #self.diag("exhausted search for tag file for %s", source)
            return ""
        #self.diag("Nope. :-| %s does NOT exist", tagsFile)
      return ""

   def addSource(self, source):
      if not source:
         return ""
      tagsFile = self.findTagFile(source)
      if tagsFile:
         relativeSource = source[len(os.path.dirname(tagsFile))+1:]
         if self.convert_backslashes:
            relativeSource = string.replace(relativeSource, '\\', '/')
         if self.tags.has_key(tagsFile):
            self.tags[tagsFile].append(relativeSource)
         else:
            self.tags[tagsFile] = [ relativeSource ]

   def stripTags(self, tagsFile, sources):
     #self.diag("Removing tags for %s from tags file %s", (sources, tagsFile))
      backup = ".SAFE"
      for line in fileinput.input(files=tagsFile, inplace=1, backup=backup):
         if line[-1:] == '\n': line = line[:-1]
         if line[-1:] == '\r': line = line[:-1]
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
         cwd = os.getcwd()
         tagsDir = os.path.dirname(tagsFile)
        #tagsDirStr = string.replace(tagsDir, '\\', '\\\\')
         os.chdir(tagsDir)
         sources = self.tags[tagsFile]
         self.stripTags(tagsFile, sources)
         cmd = "ctags -a"
         for source in sources:
            if os.path.isfile(source):
               cmd += " %s" % source
        #self.diag("%s: %s", (tagsDirStr, cmd))
         (ch_in, ch_out) = os.popen2(cmd)
         for line in ch_out:
            pass
        #vim.command("echo \"%s: %s\"" % (tagsDirStr, cmd))
         os.chdir(cwd)

   def diag(self, msg, args = None):
      if self.verbose and msg:
         if args:
            print >>sys.stderr, msg % args
         else:
            print >>sys.stderr, msg

at = AutoTag(convert_backslashes = True)
import vim
at.addSource(vim.eval("expand(\"%:p\")"))
at.rebuildTagFiles()
EEOOFF
endfunction

if !exists("g:autotag_autocmd_set")
   let g:autotag_autocmd_set = 1
   autocmd BufWritePost,FileWritePost * call AutoTag ()
endif

endif " has("python")

" vim:sw=3:ts=3
