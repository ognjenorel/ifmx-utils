/**
 * Copyright 2011 Ognjen Orel
 *
 * This file is part of IFMX Table copy utility.
 *
 * migrateOnconfig is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * migrateOnconfig is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with migrateOnconfig. If not, see <http://www.gnu.org/licenses/>.
 * -----
 *
 *
 * Script to help migrating onconfig to whichever version.
 *
 * Provide actual onconfig file and onconfig.std of version your migrating to.
 *
 * Parameters that have no default value in std are appended to the end of file.
 * 
 * More info at: https://ifmx.wordpress.com/2011/11/02/migrating-your-onconfig/
 *
 */

// command line parsing specification
def cl = new CliBuilder(usage: getClass().getName() + ' options')
cl.h(longOpt: 'help', 'Show usage information and quit')
cl.i(argName: 'inputFile', longOpt: 'inputFile', args: 1, required: true, 
     'onconfig file currently in use, REQUIRED')
cl.s(argName: 'stdFile', longOpt: 'stdFile', args: 1, required: true, 
     'onconfig.std file to use as a template, REQUIRED')

def options = cl.parse(args)

File std = new File(options.s), output = new File(options.i + '.new')
List input = new File(options.i).readLines()

String param, additional
List written = new ArrayList()
def inputLines
def needsAdditional = ['VPCLASS', 'BUFFERPOOL']

output.delete()
output.createNewFile()

std.eachLine { stdLine ->
   // copy all comment or empty lines
   if (stdLine.startsWith('#') || stdLine.trim().isEmpty())
      output << stdLine + '\n'
   else {
      param = stdLine.tokenize()[0]

      if (needsAdditional.contains(param))
         additional = stdLine.tokenize(',')[0].tokenize(' ')[1]
      else
         additional = null

      inputLines = input.findAll{ 
          it.matches('(' + param + ')(\\s+)(.*)') || it.equals(param) }
      if (!inputLines.isEmpty()) {
         if (additional != null)
            inputLines = inputLines.findAll { it.contains(additional) }

         inputLines.each {
            output << it + '\n'
            written.add it
         }
      }
      else
         output << stdLine + '\n'
   }
}
// write all parameters with no default value in onconfig.std at the end
output << '\n\n### parameters with no default value in onconfig.std: \n\n'
(input - written).each {
   if (!it.trim().startsWith('#') && !it.trim().isEmpty())
      output << it + '\n'
}
