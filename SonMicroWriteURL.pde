
/*
 Write a URL to a MiFare 1k via a SonMicro RFID Readerexample
 Language: Processing
 Based on an example by Tom Igoe (http://www.tigoe.net/pcomp/code/Processing/331)
 */

// import libraries:
import processing.serial.*;
import sonMicroReader.*;

// You'll need to change these values. 
String path = "makezine.com"; // don't include the http://www.; it will be added for you
int key = 0xBB;
int writeBlock = 4;

int seeking = 0;
int wroteMessage = 0;
String tagID = "";        // the string for the tag ID
Serial myPort;            // serial port instance
SonMicroReader myReader;  // sonMicroReader instance

int  lastCommand = 0;        // last command sent
int lastTagType = 0;         // last tag type received
int lastPacketLength = 0;    // last packet length received
String lastTag = null;       // last tag ID received
int lastErrorCode = 0;       // last error code received
int[] lastResponse = null;   // last response from the reader (raw data)
int lastAntennaPower = 0;    // last antenna power received
int lastChecksum = 0;        // last checksum received

int fontHeight = 14;         // font height for the text onscreen


void setup() {
  // set window size:
  size(600,400);
  // list all the serial ports:
  println(Serial.list());

  // based on the list of serial ports printed from the 
  // previous command, change the 0 to your port's number:
  String portnum = Serial.list()[0];
  // initialize the serial port. default data rate for
  // the SM130 reader is 19200:
  myPort = new Serial(this, portnum, 19200);
  // initialize the reader instance:
  myReader = new SonMicroReader(this,myPort);
  myReader.start();
  halt();

  // create a font with the second font available to the system:
  PFont myFont = createFont(PFont.list()[2], fontHeight);
  textFont(myFont);
}

void draw() {
  // draw to the screen:
  background(255);
  fill(0);
  textAlign(CENTER);

  if (lastTag != null) {
    if (wroteMessage == 0) {
      writeMessage();
      wroteMessage = 1;
      //WriteMAD();
    }
    println("Finished writing to " + lastTag);
    halt();
    seeking = 0;
    lastTag = null;
    wroteMessage = 0;
  }
  else {
    if (seeking == 0) {
      text("Hit any key to begin reading", width/2, height/2);
    } 
    else {
      text("Hold the tag to the reader and don't move it", width/2, height/2);
    }
  }
}

void keyReleased() {
  myReader.seekTag();
  seeking = 1;
}

/*  
 This function is called automatically whenever there's 
 a valid packet of data from the reader
 */
void sonMicroEvent(SonMicroReader myReader) {
  // get all the relevant data from the last data packet:
  if (myReader.getTagString() != null) {
    lastTag = myReader.getTagString();
  }
  // get the error code and last command:
  int errorCode = myReader.getErrorCode();
  int lastCommand = myReader.getCommand();

  // a little debugging info:
  println("error code: " + hex(errorCode, 2));
  println("last command: " +  hex(lastCommand,2));
  println("last tag type: " + myReader.getTagType());
  println("last tag: " + lastTag); 
  println("-----");

  // if the last command was seekTag, then you're either waiting,
  // or ready to seek again:
  if (lastCommand == 0x82) {
    if (errorCode == 0x4C) {
      // you're waiting for a tag to appear
    }
    if (errorCode == 0) {
      // you got a successful read;
      // wat, then read again
      delay(300);
      myReader.seekTag();
    }
  }
}

void authenticate2(int thisBlock, int authentication) {

  int[] thisCommand = {
    0x85,thisBlock, authentication, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
  }; 
  myReader.sendCommand(thisCommand);
}


void halt() {
  int[] thisCommand = { 0x93 }; 
  myReader.sendCommand(thisCommand);
}

void WriteMAD() {
 
  authenticate2(1, key);
  delay(1000);
  
  char chars[] = { 0xdb, 0x00, 0x03, 0xe1, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
  String block = "";
  for (int i = 0; i < 16; i++) {
    block += chars[i];
  }
  myReader.writeBlock(1, block); 
  println("Wrote MAD");
}

void writeMessage() {

  myReader.reset();
  delay(1000);

  myReader.selectTag();
  delay(1000);
  
  authenticate2(writeBlock, key);
  delay(1000);

  int messageLen = 5 + path.length();
  char hdr[] = { 
    // NXP Tag Operation available from http://www.nxp.com/documents/application_note/AN130411.pdf
    // NFC Data Exchange Format and URI Record Type Definition: http://www.nfc-forum.org/specs/spec_license
    0x00, // Padding?
    0x00, // Padding?
    0x03, // per NXP Tag Operation 2.5.1
    (char) messageLen, // per NXP Tag Operation 2.5.1 
    0xd1,              // bitfield 1101001: bit 7 = Message Begin
    //                                      bit 6 = Message End
    //                                      bit 5 = Short Record
    //                                      bits 1-3 = "NFC Forum well-known type"
    //                                      NFC Data Exchange Format 3.2 

    0x01,                       // URI Record Type Definition A.1
    (char) (path.length() + 1), // URI Record Type Definition A.1
    0x55,                       // "U" for URI, URI Record Type Definition A.1
    
    0x01  // insert "http://www." before the string, per URI Record Type Definition A.1
  };
  char[] msg = new char[ path.length() + 1 ];
  for (int i = 0; i < path.length(); i++) {
    msg[i] = path.charAt(i);
  }
  msg[path.length()] = 0xfe;
  char[] message = concat(hdr, msg);

  int count = 0;
  String block = "";
  if (message.length > 48 ) {
    println("Total message length must be under 48!");
    return;
  }

  for (int i = 0 ; i < message.length; i++) {
    if (count == 0) {
      block = "";
    }
    count++;
    block += message[i];

    //println("i = " + i + ", len=" + message.length);

    if (count == 16 || i == message.length - 1) {

      //println("[" + block + "], " + block.length());

      myReader.writeBlock(writeBlock, block); 
      delay(2000);      

      int thisByte;
      for (int x = 0; x < 16; x++) {
        if (x < block.length()) {
          thisByte = (int)block.charAt(x);
          //print("[" + thisByte + "]");
        } 
        else {
          thisByte = 0;
        }
      } 
      //println("");


      writeBlock++;
      count = 0;
    }
  }
}

