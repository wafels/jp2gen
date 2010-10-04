#
#
# Script cobbled together from
# 
# Dive Into Python 5.4
#
# Scrapes JP2 files from remote webspace and writes them to local subdirectories
# Based on hv_aia_pull2.py
#
# TODO: better handling of spawned wget process through the subprocess module
# 
#
#

from urlparse import urlsplit
from sgmllib import SGMLParser
import shutil, urllib2, urllib, os, time, sys, calendar

# URLLister
class URLLister(SGMLParser):
        def reset(self):
                SGMLParser.reset(self)
                self.urls = []

        def start_a(self, attrs):
                href = [v for k, v in attrs if k=='href']
                if href:
                        self.urls.extend(href)


# createTimeStamp
def createTimeStamp():
	""" Creates a time-stamp to be used by all log files. """
	timeStamp = time.strftime('%Y%m%d_%H%M%S', time.localtime())
	return timeStamp

# jprint
def jprint(z):
	""" Prints out a message with a time stamp """
        print createTimeStamp() + ' : ' + z

# change2hv
def change2hv(z,localUser):
	""" Changes the file permissions, and ownership from a local user to the helioviewer identity """
        os.system('chmod -R 775 ' + z)
	if localUser != '':
		os.system('chown -R '+localUser+':helioviewer ' + z)

# hvCreateSubdir
def hvCreateSubdir(x, localUser='' ,out=True):
	"""Create a helioviewer project compliant subdirectory."""
        try:
                os.makedirs(x)
                change2hv(x,localUser)
        except:
		if out:
			jprint('Directory already exists: ' + x)

# hvSubdir
def hvSubdir(measurement,yyyy,mm,dd):
	"""Return the directory structure for helioviewer JPEG2000 files."""
	return [yyyy + '/', yyyy+'/'+mm+'/', yyyy+'/'+mm+'/'+dd+'/', yyyy+'/'+mm+'/'+dd+'/' + measurement + '/']

# dateName
def dateName(yyyy,mm,dd):
	"""Create a name from year month date""" 
	return yyyy + '_' + mm + '_' + dd

# hvFilename
def hvDateFilename(yyyy,mm,dd,nickname,measurement):
	return yyyy + mm + dd + '__' + nickname + '__' + measurement


# yyyy - four digit year
# mm - two digit month
# dd - two digit day
# remote_root - remote location of the AIA files
# staging_root - files from remote location are originally copied here, and have their permissions changes here
# ingest_root - the directory where the files with the correct permissions end up

def GetMeasurement(nickname,yyyy,mm,dd,measurement,remote_root,staging_root,ingest_root,monitorLoc,timeStamp,minJP2SizeInBytes):
	jprint('Remote root: as defined in options file')
        jprint('Local root: '+staging_root)
        jprint('Ingest root: '+ingest_root)

	#
	# Higher level storage for all dates and times
	#

        # Create the staging directory for the JP2s
        jp2_dir = staging_root + 'jp2/'
        hvCreateSubdir(jp2_dir)
        staging_storage = jp2_dir + nickname + '/'
        hvCreateSubdir(staging_storage)

	# Creating the quarantine directory - bad JP2s go here
	quarantine = staging_root + 'quarantine/'
        hvCreateSubdir(quarantine)

        # JP2s are moved to these directories and have their permissions changed, etc, so they can be read by the next stage in the ingestion process.
        ingest_dir = ingest_root + 'jp2/'
        hvCreateSubdir(ingest_dir,localUser = localUser)
        ingest_storage = ingest_dir + nickname + '/'
        hvCreateSubdir(ingest_storage,localUser = localUser)

        # The location of where the databases are stored
        dbloc = staging_root + 'db/' + nickname + '/'
        hvCreateSubdir(dbloc)

        # The location of where the logfiles are stored
        logloc = staging_root + 'log/'+ nickname +'/'
        hvCreateSubdir(logloc)

	#
	# Lower level storage - specific to a particular date and measurement
	#

	# The helioviewer subdirectory structure
	hvss = hvSubdir(measurement,yyyy,mm,dd)

        # create the staging JP2 subdirectory required
	staging_today = staging_storage + hvss[-1]
	hvCreateSubdir(staging_today)

        # create the logfile subdirectory for these data
        logSubdir = logloc + hvss[-1]
	hvCreateSubdir(logSubdir)

        # Create the logfile filename
	jprint('Time stamp for this iteration = ' + timeStamp)
        logFileName = timeStamp + '.' + hvDateFilename(yyyy, mm, dd, nickname, measurement) + '.wget.log'    

        # create the database subdirectory for this measurement
        dbSubdir = dbloc + hvss[-1]
	hvCreateSubdir(dbSubdir)

        # create the database filename
        dbFileName = hvDateFilename(yyyy, mm, dd, nickname, measurement) + '__db.csv'    

	#
        # read in the database file for this measurement and date
	#
        try:
		# Get a list of images in the subdirectory and update the database with it
		dirList = os.listdir(staging_today)
		f = open(dbSubdir + '/' + dbFileName,'w')
		f.write('This file created '+time.ctime()+'\n\n')
		count = 0
		for testfile in dirList:
			if testfile.endswith('.jp2'):
				stat = os.stat(staging_today + testfile)
				if stat.st_size > minJP2SizeInBytes:
					count = count + 1
					f.write(testfile+'\n')
				else:
					os.rename(staging_today + testfile,quarantine + testfile)
					jprint('Quarantined '+ staging_today + testfile)

		jprint('Updated database file '+ dbSubdir + '/' + dbFileName + '; number of files found = '+str(count))
        except:
                f = open(dbSubdir + '/' + dbFileName,'w')
                jp2list = ['This file first created '+time.ctime()+'\n\n']
                f.write(jp2list[0])
                jprint('Created new database file '+ dbSubdir + '/' + dbFileName)
        finally:
                f.close()

	# Read the db file
	f = open(dbSubdir + '/' + dbFileName,'r')
	jp2list = f.readlines()
	f.close()

        # put the last image in some web space
        webFileJP2 = jp2list[-1][:-1]
        if webFileJP2.endswith('.jp2'):
                webFile = monitorLoc + 'most_recently_downloaded_aia_' + measurement + '.jp2'
		shutil.copy(staging_today + webFileJP2, webFile)
                jprint('Updated latest JP2 file to a webpage: '+ webFile)
        else:
                jprint('No latest JP2 file found.')

        # Calculate the remote directory
        remote_location = remote_root + '/' + hvss[-1]

        # Open the remote location and get the file list
	try:
        	usock = urllib.urlopen(remote_location)
        	parser = URLLister()
        	parser.feed(usock.read())
        	usock.close()
        	parser.close()

	        # Check which files are new at the remote location
	        newlist = ['']
	        newFiles = False
	        newFilesCount = 0
	        for url in parser.urls:
	                if url.endswith('.jp2'):
	                        if not url + '\n' in jp2list:
	                                newFiles = True
	                                newlist.extend(url + '\n')
	                                newFilesCount = newFilesCount + 1
	        if newFilesCount > 0:
	                jprint('Number of new files found at remote location = ' + str(newFilesCount))
	        else:
	                jprint('No new files found at remote location.')

	        # Write the new filenames to a file
	        if newFiles:
			newFileListName = timeStamp + '.' + hvDateFilename(yyyy, mm, dd, nickname, measurement) + '.newfiles.txt'
			newFileListFullPath = logSubdir + '/' + newFileListName
	                jprint('Writing new file list to ' + newFileListFullPath)
	                f = open(newFileListFullPath,'w')
	                f.writelines(newlist)
	                f.close()
	                # Download only the new files
	                jprint('Downloading new files.')
	                localLog = ' -a ' + logSubdir + '/' + logFileName + ' '
	                localInputFile = ' -i ' + logSubdir + '/' + newFileListName + ' '
	                localDir = ' -P'+staging_today + ' '
	                remoteBaseURL = '-B ' + remote_location + ' '
	                command = 'wget -r -l1 -nd --no-parent -A.jp2 ' + localLog + localInputFile + localDir + remoteBaseURL
	
	                os.system(command)
	
	                # Write the new updated database file
	                jprint('Writing updated ' + dbSubdir + '/' + dbFileName)
	                f = open(dbSubdir + '/' + dbFileName,'w')
	                f.writelines(jp2list)
	                f.writelines(newlist)
	                f.close()
	                # Absolutely ensure the correct permissions on all the files
	                change2hv(staging_today,localUser)
	
			#
			# Moving the files from the staging directory to the ingestion directory
			#
			# Create the ingest_today directory
			z = 
			ingest_today = ingest_storage + hvss[-1]
	                try:
				hvCreateSubdir(ingest_storage)
				for directory in hvss:
					hvCreateSubdir(ingest_storage + directory)
	                except:
	                        jprint('Ingest directory already exists: '+ingest_today)
	
			# Read in the new filenames again
	                f = open(logSubdir + '/' + newFileListName,'r')
	                newlist = f.readlines()
	                f.close()
			jprint('New files ingested are as follows:')
			for entry in newlist:
				jprint(entry)
	                # Move the new files to the ingest directory
	                for name in newlist:
	                        newFile = name[:-1]
	                        if newFile.endswith('.jp2'):
	                                shutil.copy2(staging_today + newFile,ingest_today + newFile)
					change2hv(ingest_today + newFile,localUser)
		else:
                	jprint('No new files found at ' + remote_location)
	except:
		jprint('Problem opening connection to '+remote_location+'.  Continuing with loop.')
	        newFilesCount = -1
	return newFilesCount

# Get the JP2s
def GetJP2(nickname,yyyy,mm,dd,measurement,remote_root,staging_root,ingest_root,monitorLoc,minJP2SizeInBytes,count = 0, redirect = False, daysBack = 0):
	t1 = time.time()
	timeStamp = createTimeStamp()
	# Standard output + error log file names
	stdoutFileName = timeStamp + '.' + yyyy + '_' + mm + '_' + dd + '__'+nickname+'__' + measurement + '.stdout.log'
	stderrFileName = timeStamp + '.' + yyyy + '_' + mm + '_' + dd + '__'+nickname+'__' + measurement + '.stderr.log'
	stdoutLatestFileName = 'latest.' + str(daysBack) + '__'+nickname+'__' + measurement + '.stdout.log'
	stderrLatestFileName = 'latest.' + str(daysBack) + '__'+nickname+'__' + measurement + '.stderr.log'

	# log subdirectory
	logSubdir = hvCreateLogSubdir(staging_root,nickname,measurement,yyyy,mm,dd)

	# Write a current file to web-space so you know what the script is trying to do right now.
	currentFile = open(monitorLoc + 'current.log','w')
	currentFile.write('Measurementlength = ' + measurement +'.\n')
	currentFile.write('Beginning remote location query number ' + str(count)+ '.\n')
	currentFile.write("Looking for files on this date = " + yyyy + mm + dd+ '.\n')
	currentFile.write('Using options file '+ options_file+ '.\n')
	currentFile.write('Time stamp = '+ timeStamp + '\n')
	currentFile.close()

	# Redirect stdout
	if redirect:
		saveout = sys.stdout
		fsock = open(logSubdir + stdoutFileName, 'w')
		sys.stdout = fsock

	# Get the data
	jprint(' ')
	jprint(' ')
	jprint('Measurementlength = ' + measurement)
	jprint('Beginning remote location query number ' + str(count))
	jprint("Looking for files on this date = " + yyyy + mm + dd)
	jprint('Using options file '+ options_file)
	nfc = GetMeasurement(nickname,yyyy,mm,dd,measurement,remote_root,staging_root,ingest_root,monitorLoc,timeStamp,minJP2SizeInBytes)
	t2 = time.time()
	jprint('Time taken in seconds =' + str(t2 - t1))
	if nfc > 0 :
		jprint('Average time taken in seconds = ' + str( (t2-t1)/nfc ) )
		
	# Put the stdout back
	if redirect:
		sys.stdout = saveout
		fsock.close()

	# Copy the most recent stdout file to some webspace.
		shutil.copy(logSubdir + stdoutFileName, monitorLoc + stdoutLatestFileName)

	return nfc

#Local root - presumed to be created
#staging_root = '/home/ireland/JP2Gen_from_LMSAL/v0.8/'

# root of where the data is
#remote_root = "http://sdowww.lmsal.com/sdomedia/hv_jp2kwrite/v0.8/jp2/AIA"

# AIA measurementlength array - constant
measurementlength = ['94','131','171','193','211','304','335','1600','1700','4500']


#
# Script must be called using an options file that defines the root of the
# remote directory and the root of the local directory
#
if len(sys.argv) <= 1:
        jprint('No options file given.  Ending.')
else:
        options_file = sys.argv[1]
        try:
                f = open(options_file,'r')
                options = f.readlines()
        finally:
                f.close()

        # Parse the options
        # [0] = remote http location
        # [1] = local subdirectory where the files are first saved to (staging)
	# [2] = local subdirectory where the JP2 files with the correct permissions are put for ingestion
	# [3] = specific year
	# [4] = specific month
	# [5] = specific day
	# [6] = specific measurementlength
	# [7] = instrument nickname
	# [8] = webspace
	# [9] = minimum acceptable file size in bytes.  Files smaller than this are considered corrupted
	# [10] = redirect output to file (True)
	# [11] = number of seconds to pause the data download for if no daya was downloaded the last time
	# [12] = minimum number of days back from the present date to consider
	# [13] = maximum number of days back from the present date to consider (note that the range command used to implement this requires a minimum value of n to go back n-1 days)
        remote_root = options[0][:-1]
        staging_root = options[1][:-1]
        ingest_root = options[2][:-1]
	startDate = (options[3][:-1]).split('/')
	endDate = (options[4][:-1]).split('/')
	measurementI = options[5][:-1]
	nickname = options[6][:-1]
	monitorLoc = options[7][:-1]
	minJP2SizeInBytes = int(options[8][:-1])
	redirectTF = options[9][:-1]
	sleep = int(options[10][:-1])
	daysBackMin = int(options[11][:-1])
	daysBackMax = int(options[12][:-1])

	# Re-direct stdout to a logfile?
	if redirectTF == 'True':
		redirect = True
	else:
		redirect = False


	# Days back defaults
	if daysBackMin <= -1:
		daysBackMin = 0
	if daysBackMax <= -1:
		daysBackMax = 2

	# Main program
	if ( (startDate[0] =='-1') or (startDate[1]=='-1') or (startDate[2]=='-1') or (endDate[0]=='-1') or (endDate[1]=='-1') or (endDate[2]=='-1') ):
		# repeat starts here
		count = 0
		while 1:
			count = count + 1
			gotNewData = False
			for daysBack in range(daysBackMin,daysBackMax):

				# get  date in UT
				Y = calendar.timegm(time.gmtime()) - daysBack*24*60*60
				yyyy = time.strftime('%Y',time.gmtime(Y))
				mm = time.strftime('%m',time.gmtime(Y))
				dd = time.strftime('%d',time.gmtime(Y))

				# Go through each measurement
				for measurement in measurementlength:
					nfc = GetJP2(nickname,yyyy,mm,dd,measurement,remote_root,staging_root,ingest_root,monitorLoc,minJP2SizeInBytes,count = count,redirect = redirect,daysBack = daysBack)
					if nfc > 0:
						gotNewData = True
			if not gotNewData:
				time.sleep(sleep)

	else:
		getThisDay = time.mktime((int(startDate[0]),int(startDate[1]),int(startDate[2]),0, 0, 0, 0, 0, 0))
		finalDay = time.mktime((int(endDate[0]),int(endDate[1]),int(endDate[2]),0, 0, 0, 0, 0, 0))
		while getThisDay <= finalDay:
			yyyy = time.strftime('%Y',time.gmtime(getThisDay))
			mm = time.strftime('%m',time.gmtime(getThisDay))
			dd = time.strftime('%d',time.gmtime(getThisDay))
			if measurementI == '-1':
				for measurement in measurementlength:
					nfc = GetJP2(nickname,yyyy,mm,dd,measurement,remote_root,staging_root,ingest_root,monitorLoc,minJP2SizeInBytes,count = 0,redirect = redirect)
			else:
				nfc = GetJP2(nickname,yyyy,mm,dd,measurementI,remote_root,staging_root,ingest_root,monitorLoc,minJP2SizeInBytes,count = 0,redirect = redirect)
			getThisDay = getThisDay + 24*60*60
