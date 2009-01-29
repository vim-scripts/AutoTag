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
import time

# Just in case the ViM build you're using doesn't have subprocess
if sys.version < '2.4':
   def do_cmd(cmd, cwd):
      old_cwd=os.getcwd()
      os.chdir(cwd)
      (ch_in, ch_out) = os.popen2(cmd)
      for line in ch_out:
         pass
      os.chdir(old_cwd)

   import traceback
   def format_exc():
      return ''.join(traceback.format_exception(*list(sys.exc_info())))

else:
   import subprocess
   def do_cmd(cmd, cwd):
      p = subprocess.Popen(cmd, shell=True, stdout=None, stderr=None, cwd=cwd)

   from traceback import format_exc

def echo(str):
   str=str.replace('\\', '\\\\')
   str=str.replace('"', "'")
   vim.command("redraw | echo \"%s\"" % str)

def diag(verbose, level, msg, args = None):
   if msg and args:
      msg = msg % args
   if level <= verbose:
      echo(msg)
   if level < 0:
      time.sleep(1)

def goodTag(line, excluded):
   if line[0] == '!':
      return True
   else:
      f = string.split(line, '\t')
      if len(f) > 3 and not f[1] in excluded:
         return True
   return False

class AutoTag:
   __fiveMB = 1024 * 1024 * 5
   __level = 1
   __verbose = 1

   def __init__(self, excludesuffix="", ctags_cmd="ctags", verbose=0):
      self.tags = {}
      self.excludesuffix = [ "." + s for s in excludesuffix.split(".") ]
      verbose = long(verbose)
      if verbose > 0:
         self.verbose = verbose
      else:
         self.verbose = 0
      self.sep_used_by_ctags = '/'
      self.ctags_cmd = ctags_cmd
      self.count = 0

   def findTagFile(self, source):
      ( drive, file ) = os.path.splitdrive(source)
      while file:
         file = os.path.dirname(file)
         tagsFile = os.path.join(drive, file, "tags")
         if os.path.isfile(tagsFile):
            st = os.stat(tagsFile)
            if st:
               size = getattr(st, 'st_size', None)
               if size is not None and size > AutoTag.__fiveMB:
                  self.__diag(AutoTag.__level, "Ignoring excluded file " + source)
                  return None
            return tagsFile
         elif not file or file == os.sep or file == "//" or file == "\\\\":
            return None
      return None

   def addSource(self, source):
      if not source:
         return
      if os.path.basename(source) == "tags":
         self.__diag(AutoTag.__level, "Ignoring tags file")
         return
      if os.path.splitext(source)[1] in self.excludesuffix:
         self.__diag(AutoTag.__level, "Ignoring excluded file " + source)
         return
      tagsFile = self.findTagFile(source)
      if tagsFile:
         relativeSource = source[len(os.path.dirname(tagsFile)):]
         if relativeSource[0] == os.sep:
            relativeSource = relativeSource[1:]
         if os.sep != self.sep_used_by_ctags:
            relativeSource = string.replace(relativeSource, os.sep, self.sep_used_by_ctags)
         if self.tags.has_key(tagsFile):
            self.tags[tagsFile].append(relativeSource)
         else:
            self.tags[tagsFile] = [ relativeSource ]

   def stripTags(self, tagsFile, sources):
      self.__diag(AutoTag.__level, "Stripping tags for %s from tags file %s", (",".join(sources), tagsFile))
      backup = ".SAFE"
      for l in fileinput.input(files=tagsFile, inplace=True, backup=backup):
         l = l.strip()
         if goodTag(l, sources):
            print l
      os.unlink(tagsFile + backup)

   def updateTagsFile(self, tagsFile, sources):
      tagsDir = os.path.dirname(tagsFile)
      self.stripTags(tagsFile, sources)
      cmd = "%s -a " % self.ctags_cmd
      for source in sources:
         if os.path.isfile(os.path.join(tagsDir, source)):
            cmd += " '%s'" % source
      self.__diag(AutoTag.__level, "%s: %s", (tagsDir, cmd))
      do_cmd(cmd, tagsDir)

   def rebuildTagFiles(self):
      for (tagsFile, sources) in self.tags.items():
         self.updateTagsFile(tagsFile, sources)

   def __diag(self, level, msg, args = None):
      diag(AutoTag.__verbose, level, msg, args)
EEOOFF

function! AutoTag()
python << EEOOFF
try:
    if long(vim.eval("g:autotagDisabled")) == 0:
        at = AutoTag(vim.eval("g:autotagExcludeSuffixes"), vim.eval("g:autotagCtagsCmd"), long(vim.eval("g:autotagVerbosityLevel")))
        at.addSource(vim.eval("expand(\"%:p\")"))
        at.rebuildTagFiles()
except:
    diag(1, -1, format_exc())
EEOOFF
endfunction

if !exists("g:autotagDisabled")
   let g:autotagDisabled=0
endif
if !exists("g:autotagVerbosityLevel")
   let g:autotagVerbosityLevel=0
endif
if !exists("g:autotagExcludeSuffixes")
   let g:autotagExcludeSuffixes="tml.xml.text.txt"
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
