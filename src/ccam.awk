# Copyright 2022-2024 James Delancey
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
#
# ccam -- IP camera management software written in AWK.
# 
# This software will manage streaming and saving video from IP cameras
# to a drive.  Free space of the drive is also managed.  All settings
# can be specified on the command line.  This software has no dependencies
# outside of the gawk interpreter (developed on V5.10 on MinGW).
# 
# Example:
#   This is WIP.  Just fire it up with the command line and pass the options
#   that are added in the future.
# 
#       $ awk -f ccam.awk
# 
# Versions:
#   * 0.0.1     2022-10-01      Initial version written in AWK (GAWK 5.10 MinGW)
#
# Todo:
#   * 2022-10-01  Add ffmpeg restart for no log.  Restarts FFMPEG when
#                   not recording, with signal coming from lack of
#                   logging by the process.
#   * 2022-10-01  Add CLI parser to configure the context for runtime
#   * 2022-10-01  Add priority queue for file purging and loading thereof
#   * 2022-10-01  Add file purging timer logic
#   * 2022-10-01  Add check for binary dependencies and versions
# 

BEGIN {
  # Global constants
  EXIT_CODE["SUCCESS"] = 0
  EXIT_CODE["FAILURE"] = 1
  FILEOUT["STDERR"] = "/dev/stderr"

  # Global vars
  context["cams"][0]["user"] = "admin"
  context["cams"][0]["passwd"] = "12345"
  context["cams"][0]["url"] = "rtsp://"
  # Begin main
}

function get_child_pid_by_process_name(process_name)
{
  # Get a PID for a process matching a name.
  #  
  # This function works in the MinGW environment in Windows.  A
  # process name string is provided to be regex matched with
  # the processes returned from the system shell call to ps.  If
  # this function is used in another environment, make sure that
  # the PS_COLUMN_* constants match what is expected from the
  # local ps call.
  #  
  # Args:
  #     process_name (string): The first parameter.
  #  
  # Returns:
  #     strnum: The PID which regex matches the process_name.
  #  

  CMD = "/usr/bin/ps"
  ERROR_GETLINE_TIMEOUT = "error in get_child_pid_by_process_name: getline from CMD process is zero length"
  ERROR_NO_RESULT_FOUND = "error in get_child_pid_by_process_name: no resulting pid was found"
  PROCESSES_TO_SKIP[0] = "ps"
  PROCESSES_TO_SKIP[1] = "gawk"
  PS_COLUMN_COMMAND = "8"
  PS_COLUMN_PID = "1"
  PS_COLUMN_PPID = "3"
  EOF = 0
  DONT_SKIP_LINE = 0
  SKIP_LINE = 1
  EMPTY_STRNUM = "0"
  
  cmdout = ""
  cmdout_skipline = 0
  cmdoutarray[0]
  pid = 0
  ppid = PROCINFO["pid"]
  result = STRNUM_ZERO
  
  while ((CMD | getline cmdout) != EOF) {
    cmdout_skipline = DONT_SKIP_LINE
    
    if (cmdout == "") {
      print(ERROR_GETLINE_TIMEOUT) > FILEOUT["STDERR"]
      exit (EXIT_CODE["FAILURE"])
    }
    
    split(cmdout, cmdoutarray, FS)
    for (i in PROCESSES_TO_SKIP) {
      if (cmdoutarray[PS_COLUMN_COMMAND] ~ PROCESSES_TO_SKIP[i]) {
        cmdout_skipline = SKIP_LINE
      }
    }
    
    if ((cmdout_skipline == DONT_SKIP_LINE) && (cmdoutarray[PS_COLUMN_PPID] ~ ppid) && (cmdoutarray[PS_COLUMN_COMMAND] ~ process_name)) {
      result = cmdoutarray[PS_COLUMN_PID]
      break
    }
  }
  
  close(CMD)
  if (result == STRNUM_ZERO) {
    print(ERROR_NO_RESULT_FOUND) > FILEOUT["STDERR"]
    exit (EXIT_CODE["FAILURE"])
  }
  return result
}
