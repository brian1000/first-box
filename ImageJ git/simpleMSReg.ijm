macro "msregAlign [3]" {
	
	run("Close All");
	
	//initialize (get raw file directory, etc)
	rawdir = getDirectory("Choose Directory with raw images ");
	list = getFileList(rawdir);
	
	//set max probes per hybe rounds [DONT CHANGE]...can't be higher than 6 on this version of Fiji
	max_probes=6;
	
	//get path to temp directory
 	tmp = getDirectory("temp");
 
	/*create temp directory for file processing;
	temp dir is deleted after alignment step*/
	mainDir = tmp+"tempMSReg"+File.separator;
	File.makeDirectory(mainDir);
	if (!File.exists(mainDir))
	    exit("Unable to create directory");
	 
	
	//create directory for saved results
	resultsDir=File.getParent(rawdir) + File.separator + "msregResults"  + File.separator ;
	File.makeDirectory(resultsDir);
	
	//create TM & nonTM subfolders
	File.makeDirectory(mainDir + "TMs" + File.separator);
	File.makeDirectory(mainDir + "nonTMs" + File.separator);
	
	//create renamed raw subfolder
	File.makeDirectory(mainDir + "namedRaw" + File.separator);

	setBatchMode(true);
	//clean up file names, store in namedRaw 
	for (i=0; i<list.length; i++) {
		path = rawdir+list[i];
		if (!endsWith(path,"/")) open(path);
			
			list[i]=replace(list[i],".tif","");
			splitname=split(list[i],"_");
			probe=splitname[4];
			hybe=splitname[3];
			name= hybe + "_" + probe;
			saveAs("Tiff", mainDir + "namedRaw" + File.separator+name);
			run("Close All");
	}
	
//-----------------------------------------------------------------------------------
	//separate TMs from nonTMs
	list = getFileList(mainDir+"namedRaw");
	
	for (i=0; i<list.length; i++) {
		path = mainDir + "namedRaw"+File.separator+list[i];
		if (matches(list[i],".*TM.*")) {
			TMs = Array.concat(TMs,list[i]);
			open(path);
			saveAs("Tiff", mainDir + "TMs" + File.separator+list[i]);
			
		}
		else {
			nonTMs = Array.concat(nonTMs, list[i]);
			open(path);
			saveAs("Tiff", mainDir + "nonTMs" + File.separator+list[i]);
			run("Close All");
		}
	}
	
	
	TMs = Array.deleteIndex(TMs,0);
	nonTMs = Array.deleteIndex(nonTMs,0);
	//Array.print(nonTMs);
		
	//make txt file with Channel Order: 
	txt = File.open(resultsDir + "chnlOrder.txt");		
	print(txt,"CHANNEL ORDER:"+"\n");
	for (i=0;i<nonTMs.length;i++){
	nonTMs[i]=replace(nonTMs[i],".tif","");
	splitname=split(nonTMs[i],"_");
	name=splitname[1];
	print(txt,"'"+name+"',"+"\n");
	}
	File.close(txt);

	//get number of hybe rounds
	num_hybe = TMs.length;
	print("Number of Hybridization Rounds: " + num_hybe);
//---------------------------------------------------------------------------	
	//count difference between hybe probe and max probe, equalzie number of images per round by adding blanks with filler()	
	for (i=0; i<num_hybe; i++) {
		path=mainDir + "nonTMs" + File.separator;
		d=counter(nonTMs,i+1);
		print("there are "+d+" less probes than max probes");
		if (d>0) {
			filler(d,i,path);
		}	
	}

//------------------------------------------------------------------------------
	/*create slice array for final substack selection; this will let us avoid 
	the blank fillers when trimming the aligned stack with substack()*/
	slice = newArray(0);
	sliceTM = newArray(0);
	for (i=0; i<num_hybe; i++) {
		d=counter(nonTMs,i+1);
		k=slice_selector(i,d,max_probes);
		slice = Array.concat(slice,k);
		j = i*(max_probes+1)+1;
		sliceTM = Array.concat(sliceTM,j);
	}
	
	//transform the array of slices into strings before calling substack()
	slice_string = "";
	for (i=0;i<slice.length-1;i++) {
		slice_string = slice_string + toString(slice[i])+",";
	}
	slice_string = slice_string + toString(slice[slice.length - 1]);//final argument shouldn't have a comma at the end
	print(slice_string);
	
	TM_string = "";
	for (i=0;i<num_hybe-1;i++) {
		TM_string = TM_string + toString(sliceTM[i])+",";
	}
	TM_string = TM_string + toString(sliceTM[sliceTM.length - 1]);//final argument shouldn't have a comma at the end
	print(TM_string);
//-------------------------------------------------------------------------
	
	//make TM stack; this will be the first channel of hyperstack which the linear SIFT plugin will use to obtain the transformations; transforms from brightfield stack will be applied to all other channels with probes
	list = getFileList(mainDir + "TMs");
	for (i=0; i<num_hybe;i++) {
		path = mainDir + "TMs" + File.separator + list[i];
		if (!endsWith(path,"/")) open(path);	
	}
	run("Images to Stack","name=TM_Stack");
	saveAs("Tiff",mainDir+"TM_Stack");
	run("8-bit");
	run("Enhance Contrast...", "saturated=0.35 normalize process_all");
	run("Find Edges", "stack");
	
//-----------------------------------------------------------------------------------
	//make probe stacks (p1,p2,etc) that hold 'equal' number of probes from each hybe round. Apply transform from c1 to all other channels
	list = getFileList(mainDir +"nonTMs");
	for (i=0; i<max_probes;i++) {
	p_folder=mainDir + "p"+i+1+File.separator;
	File.makeDirectory(p_folder);
		for (f=0; f<num_hybe;f++) {
			path = mainDir+"nonTMs"+File.separator+list[i+max_probes*f];
			if (!endsWith(path,"/")) open(path);
			rgbto8bit();
			run("8-bit");
			saveAs("Tiff", p_folder + list[i+max_probes*f]);
		}
		list_p = getFileList(p_folder);
		list_pTotal = Array.concat(list_pTotal,list_p);
		run("Images to Stack","name=p"+i+1+"stack");
		saveAs("Tiff",mainDir+"pStack"+i+1);
	}

//----------------------------------------------------------------------------------------	

	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	tmpfile  = mainDir;
	tmpfile += "msrTransforms-" + year + "-" + month + "-" + dayOfMonth + ".txt";
	
	run("MultiStackReg", "stack_1=TM_Stack.tif" 
		+ " action_1=Align"
		+ " file_1=[" + tmpfile + "]"
		+ " stack_2=None"
		+ " action_2=Ignore"
		+ " file_2=[]"
		+ " transformation=[Rigid Body] save");

		
	for (i=0; i<max_probes;i++) {
	run("MultiStackReg", "stack_1=pStack" + i+1 +".tif"+
		" action_1=[Load Transformation File]" +
		" file_1=[" + tmpfile + "]" +
		" stack_2=None" +
		" action_2=Ignore" +
		" file_2=[]" +
		" transformation=[Rigid Body]");
	}	
//----------------------------------------------------------------------------------------------------------------	
	//create string for mergechannels(); similar idea to strings made for substack()
	mc_string = "c1=TM_Stack.tif";
	for (i=0; i<max_probes; i++) {
	mc_string = mc_string + " c"+toString(i+2)+"=pStack"+toString(i+1)+".tif";
	}
	run("Merge Channels...", mc_string +" create ignore");//each stack becomes a channel of a hyperstack (c,z,t)=(7,num_hybe,1)

	setBatchMode(false);
	run("Hyperstack to Stack");//flattening hyperstack to stack retrieves original order of probes as they were in nonTMs folder
	z_slices = num_hybe * (max_probes + 1);
	run("Properties...", "channels=1 slices="+z_slices+ " frames=1 pixel_width=1.0000 pixel_height=1.0000 voxel_depth=1.0000");//adjust stack dimensions to z-stack only before calling substack()
	run("Make Substack...", "slices="+slice_string);
	saveAs("Tiff", resultsDir+"aligned probes");

	
	selectWindow("Composite");
	run("Make Substack...", "slices="+TM_string);
	saveAs("Tiff", resultsDir+"aligned TMs");

	//close or delete unecessary files. 
	selectWindow("Composite");
	close();
	delTemp();
	Dialog.create("Done")
	Dialog.show();
	
}
/*macro end===============================================================================================================
===========================================================================================================================
===========================================================================================================================
*/

//counts how many probes come from a certain hybridization round (doesnt include TMs) and returns difference from max_probes
function counter(list, i) {
	count=0;
	i=toString(i);
	i=i+"_";
	for (f=0; f<list.length;f++){
		if (list[f].contains(i)) {
		count++; 
		}
	}
	diff=max_probes-count;
	return(diff);
}

//creates new filler images,"blanks", to equalize probe size of each hybe round   
function filler(diff,i,path) {
	i++;
	i=toString(i);
	for (f=0; f<diff; f++) {
		title=i+"_xxx"+f;
		call("ij.gui.ImageWindow.setNextLocation", 10, 10);
		newImage(title,"8-bit black",1024,1024,1);//might be issue since raws are 16bit but blanks are 8bit...
		saveAs("Tiff", path+title);
		run("Close All");
		
	}
}

//create array to represent which of the slices in the final hyperstack-to-stack z-stack contain actual data and not filler. 
function slice_selector(i,d,max_probes) {
	slice_per_hybe = max_probes-d;
	t = Array.getSequence(slice_per_hybe);
	for (f=0;f<t.length;f++) {
		t[f]=t[f]+i*(max_probes +1)+2;
	}
	return t;
}

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


function delTemp() {  

  list = getFileList(mainDir+ "namedRaw" + File.separator);
  for (i=0; i<list.length; i++){
      ok = File.delete(mainDir+"namedRaw"+ File.separator+list[i]);
  }
  list = getFileList(mainDir+ "TMs" + File.separator);
  for (i=0; i<list.length; i++){
      ok = File.delete(mainDir+"TMs"+ File.separator+list[i]);
  }
  list = getFileList(mainDir+ "nonTMs" + File.separator);
  for (i=0; i<list.length; i++){
      ok = File.delete(mainDir+"nonTMs"+ File.separator+list[i]);
  }
  list = getFileList(mainDir+ "p1" + File.separator);
  for (i=0; i<list.length; i++){
      ok = File.delete(mainDir+"p1"+ File.separator+list[i]);
  }
    list = getFileList(mainDir+ "p2" + File.separator);
  for (i=0; i<list.length; i++){
      ok = File.delete(mainDir+"p2"+ File.separator+list[i]);
  }
   list = getFileList(mainDir+ "p3" + File.separator);
  for (i=0; i<list.length; i++){
      ok = File.delete(mainDir+"p3"+ File.separator+list[i]);
  }
    list = getFileList(mainDir+ "p4" + File.separator);
  for (i=0; i<list.length; i++){
      ok = File.delete(mainDir+"p4"+ File.separator+list[i]);
  }
   list = getFileList(mainDir+ "p5" + File.separator);
  for (i=0; i<list.length; i++){
      ok = File.delete(mainDir+"p5"+ File.separator+list[i]);
  }
    list = getFileList(mainDir+ "p6" + File.separator);
  for (i=0; i<list.length; i++){
      ok = File.delete(mainDir+"p6"+ File.separator+list[i]);
  }
   list = getFileList(mainDir);
  for (i=0; i<list.length; i++){
      ok = File.delete(mainDir+list[i]);
  }
  ok = File.delete(mainDir);

}
