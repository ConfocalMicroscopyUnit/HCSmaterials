/*******************HCS-Analysis*******************
/* Written by Joquim Soriano Felipe (ximosoriano@yahoo.es).
 * Developed on FIJI, running on ImageJ 1.52c.
 * FIJI is under the General Public License, ImageJ is on the public domain.
 * There is no need to install additional plugins for the macto to work.
 * HCS-Analysis.ijm was designed as an image analysis routine to be used in .tif  image collections from HCS experiments.
 * HCS-Analysis computes z prime and z values.
 * Image collections should fulfill the following criteria:
 * 	- all images should be on the same folder, no sub-folders are allowed.
 * 	- image's names should code the name of the well the image comes from.
 * 	- only images are expected in the images folder.
 * 	- tif images can either be single channel images or multichannel tif images. Sets of single channel images from different channels are also accepted.
 * 	- tif images should be ordered based on creation date. On such assumption, images on the same well follow each other as whell as images from different channels on the same field.
 * 	- tif images' names should be the same length. Name's digits coding the well row and column should always occupy the same position.
 * 	In order to run HCS-Analysis simply drag and drop HCS-Analysis.ijm into FIJI's main tool bar and click the Run button on the menu that will pop up. Different graphical users interfaces will guide you through the analysis steps.
 * 	HCS-Analysis detects objects based on pixel brightness, circularity and size (which the user can choose from a pop up menu), alternatively it can run a user custom-made image analysis routine.
 * 	Such routine should be designed by the user at its convenience but its result should always be a binary image of detected objects.
 * 	HCS-Analysis measures any variable from ImageJ's set Measurement's menu (which the user can choose from a pop-up menu). Object detection channel and measurement channel do not need to be the same.
 * 	(both can be set easily in a pop-up  menu).
 * 	Morphological measurements are given in pixel units. Objects holes are filled prior to measuring.
 * 	HCS-Check-Results.ijm is a macro that was designed to be used with HCS-Analysis.ijm. It does show the detected objects in its original images so the user can
 * 	check wether object detection is being done properly.
 * 	HCS-Check-Results will be automatically installed when the "check results" option is selected when running HCS-Analysis.
 * 	HCS-Check-Results.ijm should be saved in imageJ's Macro's folder.
 * 	HCS-Analysis creates a text file when executed (HCS-Check-Results-parameters.txt) in which it saves the parameters needed by HCS-Check-Results to work.
 * 	HCS-Analysis saves the following data on a result's folder:
 * 	- objects' measurments in a file per whell. Such files are organized in three folders containing: positive controls, negative controls and experimental conditions.
 * 		A resume containing variables means per well is also created.
 * 	- a ROIs' folder, containing all objects' detected ROIs per image.
 * 	- an "HCS Analyis resume.txt"  text file containing the analysis results (z´, z-scores, ...) and parameters (thresholding parameters, launchement data, ...).
 */


///////////////Set up block
getDateAndTime(yearLaunched, monthLaunched, dayOfWeek, dayOfMonthLaunched, hourLaunched, minuteLaunched, second, msec);//will be saved in HCS Analyis resume.txt
print("\\Clear");//empties the Log window
run("Close All");//closes any opened image
if(isOpen("Results"))//empties the results window
{
	IJ.deleteRows(0, nResults); 
}
roiManager("reset");
var posControlNamesArray;
var negControlNamesArray;
var nChannels;

// GUI-1 dialog's box creation***************************************************************
Dialog.create("HCS-Analysis");
Dialog.addMessage("What would you like to do?:");
Dialog.addCheckbox("Process data", true);
Dialog.addCheckbox("Check results", true);
Dialog.show;
//GUI-1 dialog's box values retrieving*******************************************************
processData=Dialog.getCheckbox();
checkResults=Dialog.getCheckbox();
if(processData==0 && checkResults==0)
{
	exit("The macro has been exited.\nNeither data processing nor results checking were selected.");
}

// GUI-2 dialog's box creation***************************************************************
Dialog.create("HCS-Analysis");
Dialog.setInsets(0,0,0);
Dialog.addMessage("Enter the images' and the results' directories, alternatively, tick to browse: ");
Dialog.addString("Images' directory:", "", 100);
Dialog.setInsets(0,20,0);
Dialog.addCheckbox("Browse to images' directory: ", false);
Dialog.addString("Results' directory:", "", 100);
Dialog.addCheckbox("Browse to results' directory: ", false);
Dialog.show;
//GUI-2 dialog's box values retrieving*******************************************************
imagesDir=Dialog.getString()+"\\";
booleanGetImagesDir=Dialog.getCheckbox();
if (booleanGetImagesDir== true)
{imagesDir = getDirectory("Choose the images' directory");}//This is considered another GUI
resultsDir=Dialog.getString()+"\\";
booleanGetResultsDir=Dialog.getCheckbox();
if (booleanGetResultsDir== true)
{resultsDir = getDirectory("Choose the results' directory");}//This is considered another GUI
print("imagesDir: "+imagesDir);
print("resultsDir: "+resultsDir);

if(processData==true)
{
File.makeDirectory(resultsDir+"ROIs/");
//End of GUI-2 dialog's box value retrieving*************************************************

// GUI-3 dialog's box creation***************************************************************
var imagesNamesArray;
imagesNamesArray=getFileList(imagesDir);
print("imagesNamesArray[0]: "+imagesNamesArray[0]);
firstImageNameWithoutExtension=substring(imagesNamesArray[0], 0, indexOf(imagesNamesArray[0], ".tif"));
Dialog.create("HCS-Analysis");
Dialog.setInsets(0,0,0);
Dialog.addMessage(imagesNamesArray[0]);
Dialog.setInsets(0,0,0);
Dialog.addMessage("Write the digits in the image's name above that codify the well plate's row and column:");
for(i=1;i<=lengthOf(firstImageNameWithoutExtension);i++)
{
	Dialog.addString("", ".", 1);
	if(i<lengthOf(firstImageNameWithoutExtension))
	{
		Dialog.addToSameRow();
	}
}
Dialog.addToSameRow();
Dialog.addMessage(".tif");
Dialog.setInsets(0,0,0);
Dialog.addMessage("(Respect digits positions, leave \".\" in unused positions).");
Dialog.setInsets(0,0,0);
Dialog.addMessage("(Use a single character per box).");
Dialog.addNumber("Enter the number of positive control samples: ", 0);
Dialog.addNumber("Enter the number of negative control samples: ", 0);
Dialog.addNumber("Enter the number of experimental samples: ", 0);
Dialog.addNumber("Enter the number of channels that were captured per field: ", 0);
Dialog.show;
//GUI-3 dialog's box values retrieving*******************************************************
regExArray=newArray(lengthOf(firstImageNameWithoutExtension));//This array contains "." in the meaningless image name digits and a character in the digits that codifiy the row and column of the well the image comes from
for(i=0;i<lengthOf(firstImageNameWithoutExtension);i++)
{
	regExArray[i]=".";
	print("regExArray["+i+"]: "+regExArray[i]);
}
for(i=0;i<(lengthOf(firstImageNameWithoutExtension));i++)
{
	currentDigit=Dialog.getString();
	print("--------- i: "+i+" --------");
	print("currentDigit: "+currentDigit);
	if(currentDigit!=".")
	{
		regExArray[i]=currentDigit;
		print("regExArray["+i+"]: "+regExArray[i]);
	}
}
regEx="";//This is a string made of the succession of elements of regExArray
for(i=0;i<lengthOf(firstImageNameWithoutExtension);i++)
{
	regEx=regEx+regExArray[i];
	print("regEx: "+regEx);
}
nPos=Dialog.getNumber();
print("nPos: "+nPos);
nNeg=Dialog.getNumber();
print("nNeg: "+nNeg);
nExp=Dialog.getNumber();
print("nExp: "+nExp);
nChannels=Dialog.getNumber();
print("nChannels: "+nChannels);
//End of GUI-3 dialog's box value retrieving*************************************************

textFile=File.open(resultsDir+"HCS Analyis resume.txt");// z', zvalues and settings are going to be saved in this file
print(textFile, "---------------HCS Analysis Results---------------");
print(textFile," ");
// GUI-4 dialog's box creation***************************************************************
Dialog.create("HCS-Analysis");
Dialog.setInsets(0,0,0);
Dialog.addMessage("Choose the variables that you want to measure:");
Dialog.addHelp("https://imagej.nih.gov/ij/docs/guide/146-30.html");
Dialog.setInsets(0,0,0);
Dialog.addMessage("(Press the Help button to get information about the variables to measure).");
measurementsLabels=newArray("Area", "Mean gray value", "Standard deviation", "Modal gray value", "Min & Max gray value", "Centroid", "Center of Mass", "Perimeter", "Bounding Rectangle", "Fit ellipse", "Shape descriptors", "Feret's Diameter", "Integrated density", "Median", "Skewness", "Kurtosis", "Area fraction", "Stack position");
measurementsLabelsDefaults=newArray(1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
Dialog.addCheckboxGroup(6, 3, measurementsLabels, measurementsLabelsDefaults);
measurmentChannelItems=newArray("1", "2", "3", "4", "5", "6");
Dialog.addChoice("Choose the channel in which you want to measure", measurmentChannelItems, 2);
detectionChannelItems=newArray("1", "2", "3", "4", "5", "6");
Dialog.addChoice("Choose the channel in which you want to detect objects", detectionChannelItems, 1);
Dialog.setInsets(0,0,0);
Dialog.addMessage("Choose a thresholding method:");
Dialog.addCheckbox("Select objects that fulfill:", true);
Dialog.addNumber("pixels are brighter than:", 312);
Dialog.addNumber("pixels are less bright than:", 65535);
Dialog.addNumber("circularity is bigger than:", 0.6);
Dialog.addNumber("size in pixels is smaller than:", 1700);//should be "Infinity" by default
Dialog.addNumber("size in pixels is bigger than:", 190);
Dialog.setInsets(0,120,0);
Dialog.addCheckbox("Tick to apply watershed after thresholding", true);
Dialog.addCheckbox("Apply a pre-programmed thresholding routine", false);
Dialog.setInsets(0,0,0);
Dialog.addString("Enter the routine's directory: ", "C:\\Desktop\\fiji-win64\\Fiji.app\\macros\\detection_macro.ijm", 100);
Dialog.setInsets(0,150,0);
Dialog.addCheckbox("Tick to browse to the thresholding routine's directory ", false);
Dialog.show;
//GUI-4 dialog's box values retrieving*******************************************************
area=Dialog.getCheckbox();
print("area: "+area);
mean=Dialog.getCheckbox();
print("meanGrayVale: "+mean);
standard=Dialog.getCheckbox();
print("standardDeviation: "+standard);
modal=Dialog.getCheckbox();
print("modalGrayValue: "+modal);
min=Dialog.getCheckbox();
print("minAndMaxGrayValue: "+min);
centroid=Dialog.getCheckbox();
print("centroid: "+centroid);
center=Dialog.getCheckbox();
print("centerOfMass: "+center);
perimeter=Dialog.getCheckbox();
print("perimeter: "+perimeter);
bounding=Dialog.getCheckbox();
print("boundingRectangle: "+bounding);
fit=Dialog.getCheckbox();
print("fitEllipse: "+fit);
shape=Dialog.getCheckbox();
print("shapeDescriptors: "+shape);
ferets=Dialog.getCheckbox();
print("feretsDiameter: "+ferets);
integrated=Dialog.getCheckbox();
print("integratedDensity: "+integrated);
median=Dialog.getCheckbox();
print("median: "+median);
skewness=Dialog.getCheckbox();
print("skewness: "+skewness);
kurtosis=Dialog.getCheckbox();
print("kurtosis: "+kurtosis);
areaFraction=Dialog.getCheckbox();
print("AreaFraction: "+areaFraction);
stack=Dialog.getCheckbox();
print("stackPosition :"+stack);
measurementChannel=Dialog.getChoice();
print("measurementChannel: "+measurementChannel);
objectDetectionChannel=Dialog.getChoice();
print("objectDetectionChannel: "+objectDetectionChannel);
applyThreshold=Dialog.getCheckbox();
print("threshold? :"+applyThreshold);
brighterThan=Dialog.getNumber();
print("brighterThan: "+brighterThan);
dimmerThan=Dialog.getNumber();
print("dimmerThan: "+dimmerThan);
circularityBiggerThan=Dialog.getNumber();
print("circularityBiggerThan: "+circularityBiggerThan);
smallerThan=Dialog.getNumber();
print("smallerThan: "+smallerThan);
biggerThan=Dialog.getNumber();
print("biggerThan: "+biggerThan);
applyWatershed=Dialog.getCheckbox();
print("applyWatershed?: "+applyWatershed);
applyUsersThresholdingRoutine=Dialog.getCheckbox();
print("applyUsersThresholdingRoutine?: "+applyUsersThresholdingRoutine);
usersThresholdingRoutineDir=Dialog.getString()+"\\";
print("usersThresholdingRoutineDir: "+usersThresholdingRoutineDir);
booleanGetUsersThresholdingRoutineDir=Dialog.getCheckbox();
print("booleanGetUsersThresholdingRoutineDir?: "+booleanGetUsersThresholdingRoutineDir);
if(booleanGetUsersThresholdingRoutineDir==true)
{usersThresholdingRoutineDir = File.openDialog("Choose the thresholding routine's");}//This is considered another GUI
print("usersThresholdingRoutineDir: "+usersThresholdingRoutineDir);
//End of GUI-4 dialog's box value retrieving*************************************************

if(applyThreshold==1 && applyUsersThresholdingRoutine==1)
{
	exit("Two thresholding methods have been selected.\nPlease choose only one and run the macro again.");
}

if(applyThreshold==0 && applyUsersThresholdingRoutine==0)
{
	exit("No thresholding method has been selected.\nPlease choose one and run the macro again.");
}


// GUI-5 dialog's box creation***************************************************************
controlLabelsArray=newArray(nPos+nNeg);
print("lengthOf(controlLabelsArray): "+lengthOf(controlLabelsArray));
for(i=1; i<=lengthOf(controlLabelsArray);i++)
{
	if(i<=nPos)
	{controlLabelsArray[i-1]="Positive Control "+i;}
	else
	{controlLabelsArray[i-1]="Negative Control "+i-nPos;}
	print("controlLabelsArray["+i-1+"]: "+controlLabelsArray[i-1]);
	
}
Dialog.create("HCS-Analysis");
Dialog.setInsets(0,0,0);
Dialog.addCheckbox("Write the name of any of the images of each control, alternatively, tick to browse.", false);//image's extension should be included
for(i=1; i<=lengthOf(controlLabelsArray);i++)
{
	Dialog.addString(controlLabelsArray[i-1], "");
}
Dialog.setInsets(0,0,0);
Dialog.addMessage("What do you want to do?");
doLabels=newArray("Get z'", "Get z-score for all experimental groups");
doDefaults=newArray(0,0);
Dialog.setInsets(0,50,0);
Dialog.addCheckboxGroup( 2, 1, doLabels, doDefaults);
Dialog.show;
//GUI-5 dialog's box values retrieving*******************************************************
booleanGetControlsDir=Dialog.getCheckbox();
posControlNamesArray=newArray(nPos);
negControlNamesArray=newArray(nNeg);
if(booleanGetControlsDir==true)
{
	for(i=0; i<nPos+nNeg; i++)
	{
		File.openDialog("Choose an image belonging to "+controlLabelsArray[i]);
		if(i<nPos&&nPos!=0)
		{
			posControlNamesArray[i]=File.name;
			print("controlLabelsArray["+i+"]: "+controlLabelsArray[i]);
			print("posControlNamesArray["+i+"]: "+posControlNamesArray[i]);		
		}
		else//(i>nPos, nPos=0)
		{
			negControlNamesArray[i-nPos]=File.name;
			print("controlLabelsArray["+i-nPos+"]: "+controlLabelsArray[i]);
			print("negControlNamesArray["+i-nPos+"]: "+negControlNamesArray[i-nPos]);		
		}
	}
}
else
{
	for(i=0; i<nPos+nNeg; i++)
	{
		print("-----------i: "+i+"----------");
		if(i<nPos&&nPos!=0)
		{		
			posControlNamesArray[i]=Dialog.getString();
			print("posControlNamesArray["+i+"]: "+posControlNamesArray[i]);
		}
		else//(i>nPos, nPos=0)
		{
			negControlNamesArray[i-nPos]=Dialog.getString();
			print("negControlNamesArray["+i-nPos+"]: "+negControlNamesArray[i-nPos]);
		}
	}	
}
computeZ=Dialog.getCheckbox();
print("computeZ: "+computeZ);
computeZFactor=Dialog.getCheckbox();
print("computeZFactor: "+computeZFactor);
//End of GUI-5 dialog's box value retrieving*************************************************
//End of GUIs--------------------------------------------------------------------
//_______________________________________________________________________________
//_______________________________________________________________________________
//Next block of code is going to compute z-scores and z'
//It will first compute the average and standard deviation of variables in negative controls (c-).
//In a loop for each c-
//1- get c- results
//2- get averages per well for each varible, save in a resume table
//3- get average and standard deviation of means from the previous Table, save in two vectors: meansArray= aver-var1, aver-var2, aver-var3. and stdDevArray=sd-var2, sd-var2, sd-var3.
//General measurement block
measurementsString="";//to be used in the setMeasurements command
resultsString="";//to be printed in HCS Analyis resume.txt
if(area==true)
{
	measurementsString=measurementsString+"area";
	resultsString=resultsString+"area, ";
}
if(mean==true)
{
	measurementsString=measurementsString+" mean";
	resultsString=resultsString+"mean gray value, ";
}
if(standard==true)
{
	measurementsString=measurementsString+" standard";
	resultsString=resultsString+"gray values' standard deviation, ";
}
if(modal==true)
{
	measurementsString=measurementsString+" modal";
	resultsString=resultsString+"modal gray value, ";
}
if(min==true)
{
	measurementsString=measurementsString+" min";
	resultsString=resultsString+"minimum gray value, maximum gray value, ";
}
if(centroid==true)
{
	measurementsString=measurementsString+" centroid";
	resultsString=resultsString+"center point (X and Y), ";
}
if(center==true)
{
	measurementsString=measurementsString+" center";
	resultsString=resultsString+"center of mass (XM and YM), ";
}
if(perimeter==true)
{
	measurementsString=measurementsString+" perimeter";
	resultsString=resultsString+"perimeter, ";
}
if(bounding==true)
{
	measurementsString=measurementsString+" bounding";
	resultsString=resultsString+"bounding rectangle (BX, BM, width and height), ";
}
if(fit==true)
{
	measurementsString=measurementsString+" fit";
	resultsString=resultsString+"primary (major), secondary (minor) axis and angle of the best fitting ellipse, ";
}
if(shape==true)
{
	measurementsString=measurementsString+" shape";
	resultsString=resultsString+"circularity, aspect ratio, roundness, solidity, ";
}
if(ferets==true)
{
	measurementsString=measurementsString+" feret's";
	resultsString=resultsString+"feret's diameter (including angle and starting coordinates), minimum feret's diameter, ";
	}
if(integrated==true)
{
	measurementsString=measurementsString+" integrated";
	resultsString=resultsString+"integrated density, raw integrated density, ";
}
if(median==true)
{
	measurementsString=measurementsString+" median";
	resultsString=resultsString+"median gray value, ";
}
if(skewness==true)
{
	measurementsString=measurementsString+" skewness";
	resultsString=resultsString+"skewness (third order moment about the mean), ";
}
if(kurtosis==true)
{
	measurementsString=measurementsString+" kurtosis";
	resultsString=resultsString+"kurtosis (fourth order moment about the mean), ";
	}
if(areaFraction==true)
{
	measurementsString=measurementsString+" area_fraction";
	resultsString=resultsString+"area fraction, ";
}
if(stack==true)
{
	measurementsString=measurementsString+" stack";
	resultsString=resultsString+"stack's slice position, ";
}
print("measurementsString: "+measurementsString);

////////////////////////////////1- get c- results
File.makeDirectory(resultsDir+"Negative Controls"); 
negResultsDir=resultsDir+"Negative Controls\\";
print("negResultsDir: "+negResultsDir);
File.makeDirectory(resultsDir+"Positive Controls");
posResultsDir=resultsDir+"Positive Controls\\";
File.makeDirectory(resultsDir+"Experimental conditions");
expResultsDir=resultsDir+"Experimental conditions\\";

var headingsArray;
var meansArray;
var stdDevArray;
if(computeZ==true)
{
	meansCalculator(negControlNamesArray, nNeg, negResultsDir, "negative controls resume");
	Array.print(meansArray);
	Array.print(stdDevArray);
	negControlMeansArray=meansArray;
	Array.print(negControlMeansArray);
	negControlStdDevArray=stdDevArray;
	Array.print(negControlStdDevArray);
	
	meansCalculator(posControlNamesArray, nPos, posResultsDir, "positive controls resume");
	Array.print(meansArray);
	Array.print(stdDevArray);
	posControlMeansArray=meansArray;
	Array.print(posControlMeansArray);
	posControlStdDevArray=stdDevArray;
	Array.print(posControlStdDevArray);
	
	print("---------+++++++++");
	Array.print(headingsArray);
	
	zPrimeArray=newArray(lengthOf(negControlMeansArray));
	for(i=0; i<lengthOf(zPrimeArray); i++)
	{
		zPrimeArray[i]=1-3*(posControlStdDevArray[i]+negControlStdDevArray[i])/abs(posControlMeansArray[i]-negControlMeansArray[i]);
	}
	Array.print(zPrimeArray);
	
	Table.create("z-prime resume");
	Table.set("  ", 0, "z'");
	for(i=2; i<lengthOf(headingsArray); i++)
	{
	Table.set(headingsArray[i], 0, zPrimeArray[i-2]);
	}
	Table.update;
	Table.save(resultsDir+"z-prime resume.txt");
	selectWindow("z-prime resume");
	//next code is writting the z-prime table to a text file
	print(textFile, "");
	print(textFile, "	"+Table.headings);
	zPrimeHeadingsArray=split(Table.headings, "	");
	for(i=0;i<Table.size;i++)
	{
		string="";
		for(j=0;j<lengthOf(zPrimeHeadingsArray);j++)
		{
			string=string+"	"+Table.getString(zPrimeHeadingsArray[j], i);
		}
		print(textFile, string);
	}
	print(textFile, "");
	selectWindow("z-prime resume");
	run("Close");
}
if(computeZFactor==true)
{meansCalculator(imagesNamesArray, nExp, expResultsDir, "experimental wells resume");}//This is the last time meansCalculator() executes
//Next code is filling HCS Analyis resume.txt
print(textFile, "");
print(textFile, "Launched on: "+dayOfMonthLaunched+"/"+monthLaunched+"/"+yearLaunched+", "+hourLaunched+":"+minuteLaunched);
getDateAndTime(yearFinished, monthFinished, dayOfWeek, dayOfMonthFinished, hourFinished, minuteFinished, second, msec);
print(textFile, "Finished on: "+dayOfMonthFinished+"/"+monthFinished+"/"+yearFinished+", "+hourFinished+":"+minuteFinished);
print(textFile, "Images directory: "+imagesDir);
print(textFile, "Results directory: "+resultsDir);
if(applyThreshold==true)
{
print(textFile, "Objects were detected on channel "+objectDetectionChannel+" using the following parameters: "+brighterThan+"<pixel intensity<"+dimmerThan+", circularity>"+circularityBiggerThan+", "+biggerThan+"<size in pixels<"+smallerThan);	
}
if(applyUsersThresholdingRoutine==true)
{
print(textFile, "Objects were detected on channel "+objectDetectionChannel+" using the following thresholding routine: "+usersThresholdingRoutineDir);	
}
//next code changes last coma for and or erases it if there is only one
print("resultsString 1: "+resultsString);
if(indexOf(resultsString, ",") != lastIndexOf(resultsString, ",") )
{
	resultsString=substring(resultsString, 0, lastIndexOf(resultsString, ","));
	comaIndex=lastIndexOf(resultsString, ",");
	resultsString=substring(resultsString, 0,comaIndex)+" and"+substring(resultsString,comaIndex+1);
	print("resultsString 2: "+resultsString);
}
else
{
	resultsString=substring(resultsString, 0, lastIndexOf(resultsString, ","));
	print("resultsString 3: "+resultsString);
}

print(textFile, "Objects were measured on channel "+measurementChannel+" for: "+resultsString);
positiveString="Positive controls on wells: "+posControlNamesArray[0];
print(textFile, positiveString);
for(i=1; i<lengthOf(posControlNamesArray);i++)
{
	print(textFile, "                            "+posControlNamesArray[i]);
}
negativeString="Negative controls on wells: "+negControlNamesArray[0];
print(textFile, negativeString);
for(i=1; i<lengthOf(negControlNamesArray);i++)
{
	print(textFile, "                            "+negControlNamesArray[i]);
}
File.close(textFile);
if(checkResults==0)
{
	showMessage("HCS-Analysis", "The macro is done.\nResults can be found at: "+resultsDir);
}
}//enf of if (processData==true)

if(checkResults==true)
{
	if(processData==false)
	{
		///////////// modified GUI-3 dialog's box creation***************************************************************
		var imagesNamesArray;
		imagesNamesArray=getFileList(imagesDir);
		print("imagesNamesArray[0]: "+imagesNamesArray[0]);
		firstImageNameWithoutExtension=substring(imagesNamesArray[0], 0, indexOf(imagesNamesArray[0], ".tif"));
		Dialog.create("HCS-Analysis");
		Dialog.setInsets(0,0,0);
		Dialog.addMessage(imagesNamesArray[0]);
		Dialog.setInsets(0,0,0);
		Dialog.addMessage("Write the digits in the image's name above that codify the well plate's row and column:");
		for(i=1;i<=lengthOf(firstImageNameWithoutExtension);i++)
		{
			Dialog.addString("", ".", 1);
			if(i<lengthOf(firstImageNameWithoutExtension))
			{
				Dialog.addToSameRow();
			}
		}
		Dialog.addToSameRow();
		Dialog.addMessage(".tif");
		Dialog.setInsets(0,0,0);
		Dialog.addMessage("(Respect digits positions, leave \".\" in unused positions.)");
		Dialog.setInsets(0,0,0);
		Dialog.addMessage("(Use a single character per box.)");
		Dialog.addNumber("Enter the number of channels that were captured per well: ", 0);
		Dialog.show;
		//GUI-3 dialog's box values retrieving*******************************************************
		regExArray=newArray(lengthOf(firstImageNameWithoutExtension));//This array contains "." in the meaningless image name digits and a character in the digits that codifiy the row and column of the well the image comes from
		for(i=0;i<lengthOf(firstImageNameWithoutExtension);i++)
		{
			regExArray[i]=".";
			print("regExArray["+i+"]: "+regExArray[i]);
		}
		for(i=0;i<(lengthOf(firstImageNameWithoutExtension));i++)
		{
			currentDigit=Dialog.getString();
			print("--------- i: "+i+" --------");
			print("currentDigit: "+currentDigit);
			if(currentDigit!=".")
			{
				regExArray[i]=currentDigit;
				print("regExArray["+i+"]: "+regExArray[i]);
			}
		}	
		nChannels=Dialog.getNumber();
		print("nChannels: "+nChannels);
	}

	run("Install...", "install="+getDirectory("macros")+"HCS-Check-Results.ijm");
	parametersFile=File.open(getDirectory("macros")+"HCS-Check-Results-parameters.txt");
	print(parametersFile, "nChannels: "+nChannels);
	print(parametersFile, "resultsDir: "+resultsDir);
	for(i=0;i<lengthOf(regExArray);i++)
	{
		print(parametersFile, "regExArray["+i+"]: "+regExArray[i]);
	}
	File.close(parametersFile);
	if(processData==true)
	{
		showMessage("HCS-Analysis", "The macro is done.\nResults can be found at: "+resultsDir+".\nPress \"OK\", then:\nPress \"1\" to check detected objects on a single image.\nPress \"2\" to check detected objects on a whole well.");
	}
	else
	{
		showMessage("HCS-Analysis", "The macro is done.\nPress \"OK\", then:\nPress \"1\" to check detected objects on a single image.\nPress \"2\" to check detected objects on a whole well.");
	}
}


/////////////////////FUNCTIONS BLOCK

function meansCalculator(namesArray, nWells, savingDir, resumeName){//Function begins
// parameters:namesArray (negControlNamesArray, posControlNamesArray, imagesNamesArray), nWells(nPos, nNeg, nExp), savingDir (negResultsDir, posResultsDir,
//expResultsDir), resumeName (negative controls resume, positive controls resume, experimental wells resume); output: meansArray and stdDevArray  which are renamed 
//(negControlMeansArray, posControlMeansArray, expMeansArray, negControlsStdDev, posControlsStdDev, expStdDev) after the funcion has been called.
//positive controls resume and negative controls resume table are also created. They contain the means per well of each measured variable, the mean of means and the standard
//deviation of means. This values are needed for calculating z' and are stored in meansArray and stdDevArray.
//The experimental wells resume table does contain the mean per well of each measured variable. Mean of means and stDev of means are meaningless and therefore are not calculated.

for(i=0; i<nWells; i++)
{//loop for each well
	wellROIsCounter=0;//It is going to be used later on to name ROIs in the ROIManager, in the same way as numbers in the well's results window
	if(isOpen("Results")){IJ.deleteRows(0, nResults);}//empties the Results Window
	print("---------i: "+i+"---------");
	if(resumeName=="experimental wells resume"){imageName=imagesNamesArray[0];}//imagesNamesArray is going to decrease in size because analyzed images are erased afterwards, consecuently imagesNamesArray[0] is going to change once the images of a well have been analyzed
	else{imageName=namesArray[i];}
	print("imageName: "+imageName);//This is the name of an image on a well
	newRegEx="";//this string will contain the regular expression that allows for opening all images on a well
	for(k=0; k<lengthOf(regExArray); k++)
	{
		if(regExArray[k]=="."){newRegEx=newRegEx+".";}
		else{newRegEx=newRegEx+substring(imageName, k, k+1);}
		print("newRegEx: "+newRegEx);
	}
	newRegEx=newRegEx+".tif";
	print("newRegEx: "+newRegEx);
	for(k=0;k<lengthOf(imagesNamesArray);k++)
	{//loop for every image file
		if(matches(imagesNamesArray[k], newRegEx))
		{
			print(imagesNamesArray[k]+" matches "+ newRegEx);
			open(imagesDir+imagesNamesArray[k]);
			openedImageName=getTitle();//to be used to name ROIs later on
			k0=k;//it will be used in the code erasing already processed images
			if(nSlices>1)//means that images are multitif (process images as multitif)
			{	
				for(j=0;j<nSlices;j++)
				{
					setSlice(j+1);
					setMetadata("Label", imagesNamesArray[k]+"-slice-"+j+1);//images are named after its labels when stacks are splat
				}						
				run("Stack to Images");
			}

			else//means that images are single .tif (process images as single .tif)
			{
				for(l=1;l<nChannels;l++)
				{
					k++;
					open(imagesDir+imagesNamesArray[k]);//Assumes that images are ordered by creation data
				}
			}

				titlesArray=getList("image.titles");
				for(j=0;j<lengthOf(titlesArray);j++)
				{//blank spaces should be removed from images titles for redirect in run("set Measurements...) to work
					print("old title: "+titlesArray[j]);		
					selectImage(titlesArray[j]);
					rename(replace(titlesArray[j], " ", "_"));
					titlesArray[j]=replace(titlesArray[j], " ", "_");
					print("new title: "+titlesArray[j]);
				}
				selectWindow(""+titlesArray[objectDetectionChannel-1]+"");
				originalImageTitle=getTitle();
				run("Duplicate...", " title=thresholding ");
				if(applyThreshold==true)
				{
					setThreshold(brighterThan, dimmerThan);
					setOption("BlackBackground", true);
					run("Convert to Mask");
					if(applyWatershed==true)
					{
						run("Fill Holes");//watershed does usually not work properly if particles' holes are not filled before implementing it
						run("Watershed");
					}
				}
				if(applyUsersThresholdingRoutine==true)
				{
					runMacro(usersThresholdingRoutineDir);//assumes that works on the object's detection channel image, that the result is a single binary image and that the macro does not modify the already opened images (if any) by means of renaming, closing all, ...
					rename("thresholding");
				}
				run("Set Scale...", "distance=0 global");
				run("Set Measurements...", ""+measurementsString+" display redirect=None decimal=3");
				run("Analyze Particles...", "size="+biggerThan+"-"+smallerThan+" pixel circularity="+circularityBiggerThan+"-1.00 exclude include add in_situ");
				selectImage("thresholding");
				close();					
				selectImage(originalImageTitle);
				selectWindow(""+titlesArray[measurementChannel-1]+"");
				roiManager("Measure");
			
			run("Close All");
			//The following block of code erases the processed image from imagesNamesArray
			print("--------K: "+k+"------");
			print("--------K0: "+k0+"------");
			precedingElementsArray=Array.trim(imagesNamesArray,k0);
			Array.print(precedingElementsArray);
			posteriorElementsArray=Array.slice(imagesNamesArray, k+1, lengthOf(imagesNamesArray));
			Array.print(posteriorElementsArray);
			imagesNamesArray=Array.concat(precedingElementsArray, posteriorElementsArray);
			Array.print(imagesNamesArray);
			k=k0-1;

			for(l=0; l<roiManager("count"); l++)
			{
				roiManager("select", l);
				roiManager("rename", wellROIsCounter+1);
				wellROIsCounter++;
			}
			print("openedImageName: "+openedImageName);
			if(roiManager("count")>0)
			{
			roiManager("Save", resultsDir+"ROIs/"+openedImageName+".zip");
			}
			roiManager("reset");
		}

		else{print(imagesNamesArray[k]+" does not match "+ newRegEx);}	
	}//end of loop for every image file

	//////////////////////////////////2- get averages per well for each varible, save in a resume table
	selectWindow("Results");
	print("savingDir: "+savingDir);
	print("imageName: "+imageName);
	//Next code blocks get wellName from newRegEx
	//They get rid of .tif at the end of newRegEx, change . for -, then get rid of - at the beggining or end of a string.
	//Improves table appearances
	if(endsWith(newRegEx, ".tif"))//removes .tif from the end of a string
	{
		wellName=substring(newRegEx, 0, lengthOf(newRegEx)-4);
		print(wellName);
	}
	wellName=replace(wellName, "\\.", "-");
	print(wellName);
	print(lengthOf(wellName));
	while(endsWith(wellName, "-"))//deletes - charachters at the begining of the well name
	{
		wellName=substring(wellName, 0, lengthOf(wellName)-1);
		print(wellName);
		}
	print("wellName: "+wellName);
	while(startsWith(wellName, "-"))//deletes - charachters at the end of the well name
	{
		wellName=substring(wellName, 1);
		print(wellName);
		}
	print("wellName: "+wellName);
//next two block of code overwrite posControlNamesArray and negControlNamesArray with the well's name
if(resumeName=="positive controls resume")
{
	posControlNamesArray[i]=wellName;
}
if(resumeName=="negative controls resume")
{
	negControlNamesArray[i]=wellName;
}
	Table.save(savingDir+"Measurements Well "+wellName+".txt");//This saves the Results table, which contains the results of every image of a well
	//Next code is going to build the resume Table, which resumes the measurements of a group of wells (namely: positive control, negative control or experimental wells)
	selectWindow("Results");
	if(i==0)//the resume table is created only once
	{
		headingsArray=split(Table.headings, "	");//contains the names of the results table headings
		print("lengthOf(headingsArray): "+lengthOf(headingsArray));
		Array.print(headingsArray);
		for(k=0; k<lengthOf(headingsArray);k++)
		{
			if(headingsArray[k]=="MinThr" || headingsArray[k] =="MaxThr")//erases MinThr and MaxThr from headingsArray, this columns appear when the limit to threshold option is checked in Set Measurements, this columns are filled with NaN which causes an error
			{
				print("headingsArray["+k+"] is MinThr or MaxThr");
				precedingElementsArray=Array.trim(headingsArray,k);
				Array.print(precedingElementsArray);
				posteriorElementsArray=Array.slice(headingsArray, k+1, lengthOf(headingsArray));
				Array.print(posteriorElementsArray);
				headingsArray=Array.concat(precedingElementsArray, posteriorElementsArray);
				Array.print(headingsArray);
				k--;
			}
		}
	
		resultsArray=newArray(nResults);//This array is going to be overwritten for each column
		Table.create("resume table");//creates a table which is an empty copy of the Results table (without MinThr and MaxThr columns), will be saved with a different name
		Table.set("Well", 0, 0);
		for(k=2; k<lengthOf(headingsArray); k++)//The 0  element of headingsArray is the row number (without a name), which is set later on
		{
			Table.set(headingsArray[k], 0, 0);
			Table.update;
		}
		Table.showRowNumbers(true);//this comand sets the row numbers column
		Table.update;
	}
	//next block of code fills the resume table
	print("i= "+i+" newRegEx: "+wellName+"------------------");
	selectWindow("resume table");
	Table.set("Well", i, wellName);
	Table.update;
	for(k=2; k<lengthOf(headingsArray);k++)//the first element of the headings Array is blank, the second is Label
	{
		print("------------"+k+"----------------");
		selectWindow("Results");
		heading=headingsArray[k];
		resultsArray=Table.getColumn(heading);
		Array.print(resultsArray);
		Array.getStatistics(resultsArray, min, max, mean,stdDev);//The results table is filled with the average per well of every variable
		print(mean);
		selectWindow("resume table");
		Table.set(headingsArray[k], i, mean);
		Table.update;
		if(resumeName=="experimental wells resume")
		{
			if(i==0&&k==2)//z-value resume table is created only once
			{
				Table.create("z-value resume");
				Table.set("Well", i, 0);
				for(l=2; l<lengthOf(headingsArray); l++)
				{Table.set(headingsArray[l], 0, 0);}
				Table.update;				
			}
			selectWindow("z-value resume");
			print("++++++++++++++   k="+k+"    i="+i+"++++++++++++++++++++++++++++++++++++++++++++++++++++++");
			print("std= "+stdDev+" negControlStdDevArray["+k-2+"]: "+negControlStdDevArray[k-2]+"mean: "+mean+" negControlMeansArray["+k-2+"]: "+negControlMeansArray[k-2]);
			zValue=1-3*(stdDev+negControlStdDevArray[k-2])/abs(mean-negControlMeansArray[k-2]);
			print("zvalue: "+zValue);
			selectWindow("z-value resume");
			Table.set(headingsArray[k], i, zValue);
			Table.set("Well", i, wellName);
			Table.update;
		}
	
		
	}
}//end of loop for each well
IJ.deleteRows(0, nResults); //empties the results window
//3- get average and standard deviation of means from the previous Table, save in two vectors: meansArray= aver-var1, aver-var2, aver-var3. and stdDevArray=sd-var2, sd-var2, sd-var3.
if(resumeName=="experimental wells resume")
{
	selectWindow("z-value resume");
	Table.save(resultsDir+"z-value resume.txt");
	//Next block of code writes the z-value resume table to a text file
	print(textFile, "");
	print(textFile, "_______________ z-values _______________");
	print(textFile,"");
	print(textFile, "	"+Table.headings);
	zValueHeadingsArray=split(Table.headings, "	");
	for(i=0;i<Table.size;i++)
	{
		string="";
		for(j=0;j<lengthOf(zValueHeadingsArray);j++)
		{
			string=string+"	"+Table.getString(zValueHeadingsArray[j], i);
		}
		print(textFile, string);
	}
	selectWindow("z-value resume");
	run("Close");
}
selectWindow("resume table");
//The mean of means and the stDev of means is only calculated in control wells (this means at least two positive and negative control wells exist)
if(resumeName=="negative controls resume"||resumeName=="positive controls resume")
{
	emptyStringArray=newArray(Table.size);
	for(i=0;i<Table.size;i++)
	{
	emptyStringArray[i]=" ";
	}
	incompleteResumeLabelsArray=newArray("mean", "std dev");
	resumeLabelsArray=Array.concat(emptyStringArray, incompleteResumeLabelsArray);
	Table.setColumn(" ", resumeLabelsArray);
	Table.update;
	
	size=Table.size;
	print("size: "+size);
	meansArray=newArray(lengthOf(headingsArray)-2);
	stdDevArray=newArray(lengthOf(headingsArray)-2);
	for(i=2; i<lengthOf(headingsArray);i++)
	{
		resultsArray=Table.getColumn(headingsArray[i]);
		Array.getStatistics(resultsArray, min, max, mean,stdDev);
		Table.set(headingsArray[i], size-2, mean);
		meansArray[i-2]=mean;
		Table.set(headingsArray[i], size-1, stdDev);
		stdDevArray[i-2]=stdDev;
		Table.update;
	}
	Array.print(meansArray);
	Array.print(stdDevArray);
}

Table.save(savingDir+resumeName+".txt");
selectWindow("resume table");
run("Close");
}//Function ends
//FUNCTION ENDS___________________________________________________________________________________________
//________________________________________________________________________________________________________
//________________________________________________________________________________________________________