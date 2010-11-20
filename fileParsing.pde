//
// refresh the XML data
//
void refreshTracks() {
  trackFilenames = fileCount(dataPath("") + "/xml/", fileExtensions);
  numTracks = trackFilenames.size();
  getTrackXML(numTracks);
}


//
// return the number of files at this path
//
ArrayList fileCount(String dir, String[] extensions) {
  int num = 0;
  ArrayList files = listFileNames(dir, extensions);
  try {
    num = files.size();
  }
  catch (NullPointerException e) {
    // likely suspect: no matching directory
  }
  return files;
}


// 
// load the track XML files and create each individual track
//
void getTrackXML(int num) {
  // turn the XML into something a little more usable
  tracklist = new Tracks[num];
  for (int i = 0; i < num; i++) {
    tracklist[i] = createTrack((String) trackFilenames.get(i));
    // pull out the track dimensions
    tracklist[i].getDimensions();
  }
}


//
// create a single track
//
Tracks createTrack(String file) {

  file = dataPath("") + "/xml/" + file;

  float ele = 0;
  float revisedEle = 0;
  int numPoints = 0;

  String[][] coordinates = getCoordinates(getRoot(file), getExtension(file));
  for (int i = 0; i < coordinates.length; i++) {
     numPoints++;
  }

  // create a throwaway object
  Tracks obj = new Tracks(numPoints);

  if (numPoints > 1) {
    // now let's go through and build a track from coordinates
    for (int i = 0; i < numPoints; i++) {

      int degreeLength = 111000;

      // assign the latitude
      if (coordinates[i][0] != null) {
        scene.averageParallel(Float.parseFloat(coordinates[i][0]));
        // pull out the raw latitude coordinates
        float phi = radians(Float.parseFloat(coordinates[i][0]));
        float adjustedPhi = degrees(0.5 * log((1 + sin(phi)) / (1 - sin(phi))));
        obj.X[i] = (adjustedPhi * degreeLength);
      }

      // assign the longitude
      if (coordinates[i][1] != null) {
        float lambda = Float.parseFloat(coordinates[i][1]);
        obj.Z[i] = 0 - (lambda * degreeLength);
      }

      // assign the elevation
      if (coordinates[i][2] != null) {
        // average out each point's elevation with the two preceding it to minimize spikes
        if (i > 1) {
          obj.Y[i] = (Float.parseFloat(coordinates[i][2]) + obj.Y[i - 1] + obj.Y[i - 2]) / 3;
        } else {
          obj.Y[i] = Float.parseFloat(coordinates[i][2]);
        }
      }
      
      // assign the time and speed, if they exist
      if (coordinates[i][3] != null) {
        obj.time[i] = coordinates[i][3];
    
        // calculate speeds
        if (i == 0) {
          obj.speed[i] = 0; 
        } else {
          // only do it if we have more than one point to compare
          if (i > 0) {

            // result will be in milliseconds, ie. 5 second difference = 5000.0 as a result
            long timeDelta = getTimeDifference(obj.time[i], obj.time[i - 1]);
            // so let's step it down to seconds
            timeDelta *= 0.001;
    
            if (timeDelta > 0) {
              // result will be in meters, ie. 44.721455
              float distanceDelta = sqrt(
                pow(findDifference(obj.X[i], obj.X[i - 1]), 2) + 
                pow(findDifference(obj.Y[i], obj.Y[i - 1]), 2) + 
                pow(findDifference(obj.Z[i], obj.Z[i - 1]), 2)
              );

              // speed = distance / time
              // we're starting with m/s, but I'd like km/h, so let's convert
              obj.speed[i] = ((distanceDelta / timeDelta) / 1000) * 3600;
    
            } else {
              // catch the division by zero error before it happens
              obj.speed[i] = 0; 
            }
          } else {
            obj.speed[i] = 0; 
          } // end if
        } // end if
      } // end if

    } // end for loop
  } // end if numPoints > 1

  return obj;

}




//
// Return all the files in a directory as an array of Strings  
// (adapted from: http://processing.org/learning/topics/directorylist.html)
//
ArrayList listFileNames(String dir, String[] extensions) {
  File file = new File(dir);
  if (file.isDirectory()) {
    // dump the files into a string array
    String[] names = file.list();
    // create an ArrayList for the final file list
    ArrayList names2 = new ArrayList();

    // run through and remove files that don't match the extension
    for (int i = 0; i < names.length; i++) {
      String fileExt = getExtension(names[i]);
      for(int j = 0; j < extensions.length; j++) {
        if (fileExt.toLowerCase().equals(extensions[j])) {
          names2.add(names[i]);
        }
      }
    }
    return names2;
  } 
  else {
    // If it's not a directory
    return null;
  }
}



//
// find the absolute difference between two numbers, 
//
float findDifference(float n1, float n2) {
  return abs(n1 - n2) / 2;
}



//
// find the time difference between two strings formatted in iso8601 format (yyyy-MM-ddTHH:mm:ssZ)
//
long getTimeDifference(String date1, String date2) {
  // code I found useful for Java's date functions:
  // http://www.coderanch.com/t/378541/Java-General/java/Convert-date-difference-format 

  // create a pair of Java Date objects
  java.util.Date currentTimeStamp = new Date();
  java.util.Date prevTimeStamp = new Date();
  // create a filter for the ISO 8601 format we're (hopefully) going to find in the XML file
  SimpleDateFormat iso8601 = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
  SimpleDateFormat iso8601milli = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");

  long timeDifference = 0;
  try {
    // now convert that XML date stamp to a Date object
    currentTimeStamp = iso8601.parse(date1);
    prevTimeStamp = iso8601.parse(date2);
    // if it worked, return the difference
    timeDifference = currentTimeStamp.getTime() - prevTimeStamp.getTime();
  }
  catch (ParseException e) {
    // likely suspects: unexpected date format
  }
  catch (NullPointerException e) {
    // likely suspects: points without a date stamp
  }
  try {
    // see if it works with milliseconds (TCX files have 'em)
    currentTimeStamp = iso8601milli.parse(date1);
    prevTimeStamp = iso8601milli.parse(date2);
    // if it worked, return the difference
    timeDifference = currentTimeStamp.getTime() - prevTimeStamp.getTime();
  }
  catch (ParseException e) {
    // likely suspects: unexpected date format
  }
  catch (NullPointerException e) {
    // likely suspects: points without a date stamp
  }
  return timeDifference;
}


//
// get the root element of the document
//
XMLElement getRoot(String file) {
  XMLElement data = new XMLElement(this, file);
  System.out.println(file);
  return(data);
}

//
// get the file extension of the document
//
String getExtension(String file) {
  return file.substring(file.length() - 3).toLowerCase();
}


//
// find the element in the DOM that holds coordinate data
// then, thanks in large part to KML's ugliness, rebuild the thing as a 2D String array
// 0 = lat, 1 = lon, 2 = ele, 3 = time (if available)
//
String[][] getCoordinates(XMLElement root, String fileType) {  

  // create the return array, initialize it with a dummy value
  String[][] coordinates = {
    {" "}
  };

  // Google .kml files
  if (fileType.equals("kml")) {
    String coordinateList = "";
    // try a couple ways of navigating to the big list of coordinates in the KML file,
    // catch the exceptions if it doesn't work. Seems a bit of a crummy way of doing it.
    try {
      // Nokia Sports Tracker uses this path
      coordinateList = root.getChild("Document/Placemark/LineString/coordinates").getContent();
    }
    catch(NullPointerException n) {
      // likely suspect: point without any useful data. No need to do anything, just ignore it.
    }
    try {
      // RunKeeper Pro uses this one
      coordinateList = root.getChild("Document/Placemark/MultiGeometry/LineString/coordinates").getContent();
    }
    catch(NullPointerException n) {
      // likely suspect: point without any useful data. No need to do anything, just ignore it.
    }
    // throw each line of coordinates into a temporary array
    String[] coordinateLines = reverse(trim(splitTokens(coordinateList)));
    // re-initialize coordinates with the proper number of points
    coordinates = new String[coordinateLines.length][4];
    String[] parsedLine;
    for (int i = 0; i < coordinateLines.length; i++) {
      parsedLine = trim(split(coordinateLines[i], ","));
      // latitude is the second value
      coordinates[i][0] = parsedLine[1];
      // longitude is the first value
      coordinates[i][1] = parsedLine[0];
      // elevation is the third value
      coordinates[i][2] = parsedLine[2];
      // KML doesn't give us times
      coordinates[i][3] = null;
    }
    
  // GPS Exchange Format .gpx files
  // used by RunKeeper Pro and GPSBabel
  } else if (fileType.equals("gpx")) {
    XMLElement trkSegNode = null, trkNode = null;
    // figure out how many elements there are
    try {
        // get the absolute number of trackpoints to determine the 
        // length of the coordinates array
        int trkptCount = 0;  // number of all points
        // gpx can have multiple <trk> 
        // so check every child of root if it is a <trk>
        for(int trkIndex = 0; trkIndex < root.getChildCount(); trkIndex++) {
            trkNode = root.getChild(trkIndex);
            if(trkNode.getName().equalsIgnoreCase("trk")) {
                for(int segIndex = 0; segIndex < trkNode.getChildCount(); segIndex++) {
                    trkSegNode = trkNode.getChild(segIndex);
                    // check that this is a <trkseg> child tag
                    if(trkSegNode.getName().equalsIgnoreCase("trkseg")) {
                        // we can't take trkNode.getChildCount() straight away, because 
                        // <trkseg> may have non-<trkpt> children, eg <name>
                        for(int trkptIndex = 0; trkptIndex < trkSegNode.getChildCount(); trkptIndex++) {
                            if(trkSegNode.getChild(trkptIndex).getName().equalsIgnoreCase("trkpt"))
                                trkptCount++;
                        }
                    }
                }
            }
        }

        // re-initialize coordinates with the proper number of points
        coordinates = new String[trkptCount][4];
        int coordinatesIndex = 0;
        
        // iterate over all <trk>
        for(int trkIndex = 0; trkIndex < root.getChildCount(); trkIndex++) {
            trkNode = root.getChild(trkIndex);
            if(trkNode.getName().equalsIgnoreCase("trk")) {
              
                // iterate over all <trkseg>      
                for(int segIndex = 0; segIndex < trkNode.getChildCount(); segIndex++) {
                    trkSegNode = trkNode.getChild(segIndex); // get trkseg
                    // check that this is a <trkseg> child tag
                    if(trkSegNode.getName().equalsIgnoreCase("trkseg") && (trkSegNode.getChildCount() > 0)) {
          
                        // process this trkseg track segment
                        for (int i = 0; i < trkSegNode.getChildCount(); i++) {
                            // parse out the relevant child elements
                            XMLElement wpt = trkSegNode.getChild(i);
                            if (trkSegNode.getChildCount() > 3) {
                                try {
                                  // get the lat and long coordinates from attributes on this particular child
                                  coordinates[coordinatesIndex][0] = trim(wpt.getStringAttribute("lat"));
                                  coordinates[coordinatesIndex][1] = trim(wpt.getStringAttribute("lon"));
                                }
                                catch(NullPointerException n) {
                                  // likely suspect: point without any useful data. No need to do anything, just ignore it.
                                }
                                // get the elevation from the first child, if it exists
                                XMLElement wpt_child;
                                for(int c = 0; c < wpt.getChildCount();c++) {
                                    wpt_child = wpt.getChild(c);
                                    if(wpt_child.getName().equalsIgnoreCase("ele")) {
                                        //elevation definition
                                        coordinates[coordinatesIndex][2] = trim(wpt_child.getContent());                
                                    } else if (wpt_child.getName().equalsIgnoreCase("time")) {
                                        coordinates[coordinatesIndex][3] = wpt_child.getContent();
                                    }
                                }
                                
                                // fill empties values with dummies
                                if (coordinates[coordinatesIndex][2] == null)
                                    coordinates[coordinatesIndex][2] = "0"; // elevation = 0
                                if (coordinates[coordinatesIndex][3] == null)
                                    coordinates[coordinatesIndex][3] = "0"; // time = 0
                                coordinatesIndex++;
                            } // end trkSegNode.getChildCount
                        } // end wpt loop
                    }
                } // end trkseg loop
            }
        } // end trk loop
    }
    catch(NullPointerException n) {
      // likely suspect: point without any useful data. No need to do anything, just ignore it.
    }
    

  // Garmin Training Center .tcx files
  } else if (fileType.equals("tcx")) {
    XMLElement node = null;
    // figure out how many elements there are
    try {
      node = root.getChild("Activities/Activity/Lap/Track");
    }
    catch(NullPointerException n) {
      // likely suspect: point without any useful data. No need to do anything, just ignore it.
      // Garmin likes these. I can't understand why.
    }
    
    // re-initialize coordinates with the proper number of points
    if ((node != null) && (node.getChildCount() > 0)) {
      coordinates = new String[node.getChildCount()][4];
      
      for (int i = 0; i < node.getChildCount(); i++) {
        // parse out the relevant child elements
        XMLElement child = node.getChild(i);

        if (child.getChildCount() > 3) {
          // can't rely on any of these being present in Garmin files, it seems
          try {
            coordinates[i][0] = trim(child.getChild("Position/LatitudeDegrees").getContent());
            coordinates[i][1] = trim(child.getChild("Position/LongitudeDegrees").getContent());
          }
          catch(NullPointerException n) {
            // likely suspect: point without any useful data. No need to do anything, just ignore it.
          }
          try {
            coordinates[i][2] = trim(child.getChild("AltitudeMeters").getContent());
          }
          catch(NullPointerException n) {
            // likely suspect: point without any useful data. No need to do anything, just ignore it.
          }
          try {
            coordinates[i][3] = child.getChild("Time").getContent();
          }
          catch(NullPointerException n) {
            // likely suspect: point without any useful data. No need to do anything, just ignore it.
          }
        } else {
          coordinates[i][0] = null; coordinates[i][1] = null;
          coordinates[i][2] = null; coordinates[i][3] = null;
        }
        
      }
    }
  }

  return(coordinates);
  
}






/*
   DOM paths to coordinates for reference:

   Path to coordinates in a GPX file from RunKeeper:
   gpx > trk (multiple) > trkseg (multiple) > trkpt (multiple)

   Path to coordinates in a GPX file from GPSBabel:
   gpx > trk (multiple) > trkseg (multiple) > trkpt (multiple)

   Path to coordinates in a KML file from RunKeeper:
   kml > Document > Placemark > MultiGeometry > LineString > coordinates

   Path to coordinates in a KML file from SportsTracker:
   kml > Document > Placemark > LineString > coordinates
   
   Path to coordinates in a TCX file from Garmin:
   TrainingCenterDatabase > Activities > Activity > Lap > Track
     Trackpoint
       Time
       Position > LatitudeDegrees, LongitudeDegrees
       AltitudeMeters
       DistanceMeters




   Some notes about latitude / longitude values. Wikipedia tells us (http://en.wikipedia.org/wiki/Decimal_degrees)
   that each degree is 111km at the equator. While it would be great to map this thing out on a sphere, there's no 
   need to make it that complicated. Distances of under a few hundred km oughtta be just fine as flat maps for now.

   +-- decimal places
   |
   |    +-- degrees
   |    |               +-- distance
   |    |               |

   0	1.0	        111 km
   1	0.1	        11.1 km
   2	0.01	        1.11 km
   3	0.001  	        111 m
   4	0.0001   	11.1 m
   5	0.00001  	1.11 m
   6	0.000001	0.111 m
   7	0.0000001	1.11 cm
   8	0.00000001	1.11 mm

   To convert from lat/lon to kilometers, we multiply by 111. Meters, 111,000. That's not a constant though;
   given degree length changes at different latitudes, it could be as low as 110.5km at the equator, or as
   high as 111.5km at 70 degrees. Not a huge margin of error, but something I might want to correct one day.
   
   For now:
      int degreeLength = 111000;
   takes care of it.
   
   I do also need to convert the GPS points to a map projection though, Mercator in this case since that's 
   what Google, Microsoft, Yahoo all use and one day I may just get Elevation talking to them. Best to be 
   on the same system. Longitude is fine as-is, but latitude needs to be run through a formula adapted from 
   the maths on http://en.wikipedia.org/wiki/Mercator_projection

*/
