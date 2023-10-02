/*initial raw Tif files titled "[date]_slidest#_section_hyberound_probe" e.x "20220524_slidest2_6-4L_1_calca"
if additional notes required to be added to name, then add note at beginning of name
for example "Good-20220524_slidest2_6-4L_1_calca"...dashes are fine 
------------------------------------------------------------------------*/
macro "batchAlign [b]" {
//initialize (get raw file directory, etc)
RawDir = getDirectory("Choose Directory with raw images ");
list = getFileList(RawDir);
Dialog.create("Alignment Round");
  	Dialog.addNumber("alignment_round", 2);
    Dialog.show();
    Align_roundd = Dialog.getNumber();

setBatchMode(true);
//obtain section/slide from file names, delete duplicates.
for (i=0; i<list.length; i++) {
	splitname=split(list[i],"_");
	section=splitname[2];
	slide=splitname[1];
	slide=replace(slide,"slidest","");
	name= slide + "_" + section;
	ssAr=Array.concat(ssAr,name);
}
ssAr=Array.deleteIndex(ssAr,0);
Array.sort(ssAr);
//Array.show(ssAr);

uniqueSS=newArray();
for (i=0; i<(ssAr.length)-1; i++) {
	if (ssAr[i] != ssAr[(i)+1]) {
		uniqueSS=Array.concat(uniqueSS,ssAr[i]);
	} 
}
uniqueSS=Array.concat(uniqueSS, ssAr[(ssAr.length)-1]);
Array.show(uniqueSS);// unique Slide&section 2_3-3L etc

//create folders&subfolders
mainDir=File.getParent(RawDir) + File.separator + "tifHub"  + File.separator ;
File.makeDirectory(mainDir);
stackDir = mainDir + "stacks";
File.makeDirectory(stackDir);

for (i=0;i<uniqueSS.length;i++) {
	ssFolders=mainDir + uniqueSS[i];
	File.makeDirectory(ssFolders);
	rawFolder=ssFolders+File.separator +"Raw"+File.separator;
	File.makeDirectory(rawFolder);
	alignedFolder=ssFolders+File.separator +"Aligned"+File.separator;
	File.makeDirectory(alignedFolder);
}

//organize rawdir into Raw folders
for (f=0; f<list.length; f++) {
path = RawDir+list[f];
if (!endsWith(path,"/")) open(path);
if (nImages>=1) {
if (true) {

	splitname=split(list[f],"_");
	section=splitname[2];
	slide=splitname[1];
	slide=replace(slide,"slidest","");
	name= slide + "_" + section;
	//print(mainDir+name+File.separator+"Raw"+File.separator+list[f]);
	saveAs("Tiff", mainDir+name+File.separator+"Raw"+File.separator+list[f]);

run("Close All");
}
}
}

//cycle AutoAlign through each section subfolder and place output in aligned folders

for (q=0;q<uniqueSS.length;q++) {
//initialize
title = "Untitled";
width=512; height=512;
alignment_round = Align_roundd;
run("Conversions...", "scale");

	//get raws from subfolders, establish path to Aligned
	rawdir = mainDir+uniqueSS[q]+File.separator+"Raw"+File.separator;
	aligneddir=File.getParent(rawdir) + File.separator + "Aligned"  + File.separator ;
	list = getFileList(rawdir);
	run("Close All");
	//get transmission images
	round1 = newArray(0);
	TMs = newArray(0);
	nonTMs = newArray(0);
	w = 0;
	h = 0;
	for (i=0; i<list.length; i++) {
		splitname = split(list[i],"_");
		hybe = splitname[3];
		probe = splitname[4];
		probe = replace(probe,".tif","");
		if (hybe == alignment_round) {
			round1 = Array.concat(round1,list[i]);
			open(rawdir + list[i]);
			if (probe == "TM") {
				run("8-bit");
				run("Enhance Contrast...", "saturated=0.3 normalize equalize");
				run("Find Edges");
				run("Enhance Contrast...", "saturated=0.3 normalize equalize");			
				rename("TMref");
				w = getWidth() ;
				h = getHeight();
			} else {
				//run("Enhance Contrast...", "saturated=0.05 normalize");

				rgbto8bit();
				run("8-bit");
				saveAs("Tiff", aligneddir + probe);
			}
		} else {
			if (probe == "TM") {
				TMs = Array.concat(TMs,list[i]);
			} else {
				nonTMs = Array.concat(nonTMs,list[i]);
			}
		}
	}
	//Array.show(TMs);
	//Array.show(nonTMs);
	//Array.show(list);
	for (i=0; i<TMs.length; i++) {
		splitname = split(TMs[i],"_");
		hybe = splitname[3];
		probe = splitname[4];
		probe = replace(probe,".tif","");
		open(rawdir + TMs[i]);
		run("8-bit");
		run("Enhance Contrast...", "saturated=0.3 normalize equalize");
		run("Find Edges");
		run("Enhance Contrast...", "saturated=0.3 normalize equalize");			
		run("Size...", "width=" + w +" height=" + h + " interpolation=Bilinear");
		run("TurboReg ", "-align -window "+TMs[i]+" 0 0 "+(w-1)+" "+(h-1)+" -window TMref 0 0 "+(w-1)+" "+(h-1)+" -rigidBody "+(w/2)+" "+(h/2)+" "+(w/2)+" "+(h/2)+" " +"0 " + (h/2)+" " +"0 " + (h/2)+" "+(w-1)+" "+(h/2)+" "+(w-1)+" "+(h/2)+" -showOutput");
		sourceX0 = getResult("sourceX", 0); // First line of the table.
		sourceY0 = getResult("sourceY", 0);
		targetX0 = getResult("targetX", 0);
		targetY0 = getResult("targetY", 0);
		sourceX1 = getResult("sourceX", 1); // Second line of the table.
		sourceY1 = getResult("sourceY", 1);
		targetX1 = getResult("targetX", 1);
		targetY1 = getResult("targetY", 1);
		sourceX2 = getResult("sourceX", 2); // Third line of the table.
		sourceY2 = getResult("sourceY", 2);
		targetX2 = getResult("targetX", 2);
		targetY2 = getResult("targetY", 2);
		selectWindow(TMs[i]);
		run("Close");			
		selectWindow("Output");
		if (nSlices>1) {
			setSlice(2);
			run("Delete Slice");
		}
		run("8-bit");
		run("Merge Channels...", "c1=Output c2=TMref create keep ignore");
		rename("align-round" + hybe);
		run("Close");
		selectWindow("Output");
		run("Close");
		currhybe = hybe;


		
		for (j=0; j<nonTMs.length; j++) {	
			splitname = split(nonTMs[j],"_");
			hybe = splitname[3];
			probe = splitname[4];
			probe = replace(probe,".tif","");
			if (hybe == currhybe) {
				open(rawdir + nonTMs[j]);
				run("8-bit");
				run("Size...", "width=" + w +" height=" + h + " interpolation=Bilinear");
				run("TurboReg ", "-transform -window "+ nonTMs[j] + " "+w+" "+h+" -rigidBody "+sourceX0 +" "+sourceY0+" "+targetX0+" "+targetY0+" "+sourceX1+" "+sourceY1+" "+targetX1+" "+targetY1+" "+sourceX2+" "+sourceY2+" "+targetX2+" "+targetY2+" -showOutput");
				selectWindow(nonTMs[j]);
				run("Close");		
				selectWindow("Output");
				if (nSlices>1) {
					setSlice(2);
					run("Delete Slice");
				}
				rgbto8bit();
				//run("Enhance Contrast...", "saturated=0.05 normalize");
				saveAs("Tiff", aligneddir + probe + ".tif");
				rename(probe);
			}
		}
	}
	run("Images to Stack");
	saveAs("Tiff", File.getParent(rawdir) + File.separator + "Aligned" + File.separator + "stack_TM.tif");
	run("Stack to Images");
	selectWindow("TMref");
	run("Close");
	run("Images to Stack");
	saveAs("Tiff", File.getParent(stackDir) + File.separator + "stacks" + File.separator +uniqueSS[q] + "_stack.tif");
}

//create list of aligned-stack basenames to easily copy/paste into JN
dirStacks = File.getParent(stackDir) + File.separator + "stacks" + File.separator;
nameList = getFileList(dirStacks);  //gets a list of all files in folder dir1
ghi = File.open(File.getParent(dirStacks) + File.separator + "stacks" + File.separator + "chnlOrder.txt");
print(ghi,"Basenames");

for (f=0; f<nameList.length-1; f++) {
	
nameList[f]=replace(nameList[f],".tif","");
print(ghi,"'"+nameList[f]+"',");

}
nameList[nameList.length-1]=replace(nameList[nameList.length-1],".tif","");
print(ghi,"'"+nameList[nameList.length-1]+"'");
run("Close All");

print(ghi," ");
print(ghi,"Channel Order");
open(dirStacks+nameList[0]+".tif");
n = nSlices
	for (i=0;i<n-1;i++) {
		setSlice(i+1);
		print(ghi,"'"+getInfo("slice.label")+"'," + "\n");
	}
setSlice(n);
print(ghi,"'"+getInfo("slice.label")+"'" + "\n");
close();
File.close(ghi);


function rgbto8bit() {
	if (bitDepth() == 24) {
		run("Set Measurements...", "mean redirect=None decimal=0");
		run("Make Composite");
		title = getTitle();
		maxchannel = 0;
		max = 0;
		for (channel = 1; channel <= 3; channel++) {
			Stack.setPosition(channel, 1, 1);
			run("Clear Results");
			run("Measure");
			curr = getResult("Mean",0);
			if (curr >= max) {
				max = curr;
				maxchannel = channel;
			}
		}
		
		run("Split Channels");
		for (channel = 1; channel <= 3; channel++) {
			selectWindow("C"+channel+"-"+title);
			if (channel == maxchannel) {
				rename(title);
				run("Grays");
			} else {
				run("Close");
			}
		}
	} else {
		run("8-bit");
	}
}

Dialog.create("Done")
Dialog.show();

}