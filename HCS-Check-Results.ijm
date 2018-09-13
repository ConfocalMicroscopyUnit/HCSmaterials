/*******************HCS-Check-Results*******************
/* Written by Joquim Soriano Felipe (ximosoriano@yahoo.es).
 * Developed on FIJI, running on ImageJ 1.52c.
 * FIJI is under the General Public License, ImageJ is on the public domain.
 * There is no need to install additional plugins for the macto to work.
 * HCS-Check-Results is designed as an image viewer to be used with HCS-Analysis.ijm.
 * HCS-Analysis.ijm was designed as an image analysis routine to be used in .tif  image collections from HCS experiments.
 * HCS-Analysis computes z prime and z values.
 * HCS-Analysis creates a text file when executed (HCS-Check-Results-parameters.txt) in which the parameters needed by HCS-Check-Results to work are saved.
 * HCS-Check-Results shows the objects detected by HCS-Analysis in its original images. It allows the user to check wether 
 * object detection is being done properly.
 * HCS-Check-Results is automatically installed when the "check results" option is selected when running HCS-Analysis. In 
 * order to use it, run HCS-Analysis.ijm, select "check results" option and follow instructions.
 * HCS-Check-Results.ijm should be saved in imageJ's Macro's folder.
 * HCS-Check-Results uses the results directory created by HCS-Analysis and the original images those results were created from. 
 * 	
*/
var label=true;
var id2;

macro "check detected objects in a field [1]"{
if(label==true)
{	
	if(isOpen(id2))//closes the previously opened window
	{close();}
	//import macro parameters from HCS_checkResultsROIs-parameters.txt
	rawParameters=File.openAsString(getDirectory("plugins")+"HCS-Check-Results-parameters.txt");
	linesArray=split(rawParameters,"\n");
	nChannels=substring(linesArray[0], indexOf("nChannels: ", linesArray[0])+lengthOf("nChannels: ")+1);
	print("nChannels: "+nChannels);
	resultsDir=substring(linesArray[1], indexOf("resultsDir: ", linesArray[1])+lengthOf("resultsDir: ")+1);
	print("resultsDir: "+resultsDir);
	//end of macro parameters import
	roiManager("reset");
	imageToCheckPath=File.openDialog("choose the image to check");
	open(imageToCheckPath);
	id1=getImageID();
	id2=id1;//id2 is used to close the previously opened image
	if(File.exists(resultsDir+"\\ROIs\\"+replace(File.getName(imageToCheckPath), ".tif", ".tif.zip"))==true)
	{
		roiManager("open", resultsDir+"\\ROIs\\"+replace(File.getName(imageToCheckPath), ".tif", ".tif.zip"));
	}
	
	if(nSlices>1)//means that images are multitif (process images as multitif)
	{
		if(roiManager("count")==0)
		{exit("No objects were detected in this field");}
		if(is("composite"))
		{
			run("Hyperstack to Stack");//transforms composite images to regular stacks
			resetMinAndMax();
			id2=getImageID();
		}
		roiManager("show all with labels");
		run("Flatten", "stack");
	}
	else if(nSlices==1 && nChannels>1)//a collection of single .tif images from different channels were captured per field
	{
		imagesDir=File.getParent(imageToCheckPath)+"\\";
		imagesNamesArray=getFileList(imagesDir);
		imageName=File.getName(imageToCheckPath);
		print("imageToCheckPath: "+imageToCheckPath);
		print("imagesDir: "+imagesDir);
		print("imageName: "+imageName);
	
		for(i=0; i<lengthOf(imagesNamesArray);i++)
		{
			if(matches(imagesNamesArray[i], imageName))
			{
				for(j=1;j<nChannels;j++)
				{
					open(imagesDir+imagesNamesArray[i+j]);		
				}
			
			}
		}	
		run("Images to Stack", "name="+replace(imageName, " ", "_")+" title=[] use");//blank spaces need to be removed from the name
		id2=getImageID();
		if(roiManager("count")==0)
		{exit("No objects were detected in this field");}
		else{
			roiManager("show all with labels");
			run("Flatten", "stack");
			}
	}
	else//only an image was captured per field
	{
		if(roiManager("count")==0)
		{exit("No objects were detected in this field");}
		roiManager("show all with labels");
		run("Flatten", "stack");
		id2=getImageID();
		selectImage(id1);
		close();
	}
}
if(isOpen("ROI Manager"))
{
	selectWindow("ROI Manager");
	run("Close");
}
}//end of macro "check detected objects in a field"

macro "check detected objects in all fields of a well [2]"{
if(label==true)
{	
	if(isOpen(id2))//closes the previously opened window
	{close();}
	//import  macro parameters from HCS_checkResultsROIs-parameters.txt
	rawParameters=File.openAsString(getDirectory("plugins")+"HCS-Check-Results-parameters.txt");
	linesArray=split(rawParameters,"\n");
	nChannels=substring(linesArray[0], indexOf("nChannels: ", linesArray[0])+lengthOf("nChannels: ")+1);
	print("nChannels: "+nChannels);
	resultsDir=substring(linesArray[1], indexOf("resultsDir: ", linesArray[1])+lengthOf("resultsDir: ")+1);
	print("resultsDir: "+resultsDir);
	regExArray=newArray(lengthOf(linesArray)-2);
	for(i=0;i<lengthOf(regExArray);i++)
	{
		regExArray[i]=substring(linesArray[i+2], indexOf("regExArray["+i+"]: ", linesArray[i+2])+lengthOf("regExArray["+i+"]: ")+1);
		print(regExArray[i]);
	}
	//end of macro parameters import
	roiManager("reset");
	imageToCheckPath=File.openDialog("Choose an image belonging to the well whose images you would like to check");
	imagesDir=File.getParent(imageToCheckPath)+"\\";
	imagesNamesArray=getFileList(imagesDir);
	imageName=File.getName(imageToCheckPath);
	print("imageToCheckPath: "+imageToCheckPath);
	print("imagesDir: "+imagesDir);
	print("imageName: "+imageName);
	
	newRegEx="";//this string will contain the regular expression that allows for opening all images on a well
	for(i=0; i<lengthOf(regExArray); i++)
	{
		if(regExArray[i]=="."){newRegEx=newRegEx+".";}
		else{newRegEx=newRegEx+substring(imageName, i, i+1);}
		print("newRegEx: "+newRegEx);
	}
	newRegEx=newRegEx+".tif";
	print("newRegEx: "+newRegEx);
	
	for(i=0;i<lengthOf(imagesNamesArray);i++)
	{
		if(matches(imagesNamesArray[i], newRegEx))
		{
			print(imagesNamesArray[i]+" matches "+ newRegEx);
			open(imagesDir+imagesNamesArray[i]);
			id1=getImageID();	
			roiManager("reset");

			if(File.exists(resultsDir+"\\ROIs\\"+replace(File.getName(imagesNamesArray[i]), ".tif", ".tif.zip"))==true)
			{
				roiManager("open", resultsDir+"\\ROIs\\"+replace(File.getName(imagesNamesArray[i]), ".tif", ".tif.zip"));
			}		
			if(nSlices>1)//means that images are multitif (process images as multitif)
			{
				for(j=0;j<nSlices;j++)
				{
					setSlice(j+1);
					setMetadata("Label", imagesNamesArray[i]+"-slice-"+j+1);//images are named after its labels when stacks are splat
				}
				if(is("composite"))
				{
					run("Hyperstack to Stack");
					resetMinAndMax();
					}//transforms composite images to regular stacks
				roiManager("show all with labels");
				if(roiManager("count")>0)
				{run("Flatten", "stack");}
				run("Stack to Images");			
			}
			else if(nSlices==1 && nChannels>1)//a collection of single .tif images from different channels were captured per field
			{

					waitForUser("2");
				roiManager("show all with labels");
				if(roiManager("count")>0)
				{run("Flatten", "stack");}
				selectImage(id1);
				close();
				for(j=1;j<nChannels;j++)
				{
					i++;
					open(imagesDir+imagesNamesArray[i]);//Assumes that images are set by creation data
					id1=getImageID();
					roiManager("show all with labels");
					if(roiManager("count")>0)
					{run("Flatten", "stack");}
					selectImage(id1);
					close();		
				}
			}
			else//only an image was captured per field
			{
				if(roiManager("count")>0)
				{
					roiManager("show all with labels");
					run("Flatten", "stack");
					selectImage(id1);
					close();
					}
			}
		}
	}
	//The following block of code is going to get the name of the well
	if(endsWith(newRegEx, ".tif"))//removes .tif from the end of a string
	{
		wellName1=substring(newRegEx, 0, lengthOf(newRegEx)-4);
		print(wellName1);
	}

	wellName="Well ";
	for(i=0;i<lengthOf(wellName1);i++)
	{
		if(substring(wellName1, i, i+1)!=".")
		{
			wellName=wellName+substring(newRegEx, i, i+1);
			print(wellName);
		}
	}	
	run("Images to Stack", "name="+replace(wellName, " ", "_")+" title=[] use");
	id2=getImageID();
	if(roiManager("count")==0)
	{exit("No objects were detected in this well");}
}		
if(isOpen("ROI Manager"))
{
	selectWindow("ROI Manager");
	run("Close");
}
}//end of macro check detected objects in all fields of a well

macro "Unistall Check results [3]"{
	if(label==true)
	{
		if(isOpen(id2))//closes the previously opened window
		{close();}
		showMessage("HCS-Analysis", "HCS Check results has been uninstalled.\nRun HCS-Analysis again if you wish to continue checking results.");
		label=false;
		if(isOpen("ROI Manager"))
		{
			selectWindow("ROI Manager");
			run("Close");
		}
	}
}