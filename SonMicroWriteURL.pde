
/*
 Write a URL to a MiFare 1k via a SonMicro RFID Readerexample
 Language: Processing
 */


// import libraries:
import processing.serial.*;
import sonMicroReader.*;

String path = "as220.org";

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
    text(lastTag, width/2, height/2);
    if (wroteMessage == 0) {
      writeMessage();
      wroteMessage = 1;
    }
  }
  else {
    text("Hit any key to begin reading", width/2, height/2);
  }
}

void keyReleased() {
  myReader.seekTag();
}


void writeMessage() {

  myReader.selectTag();
  delay(2000);

  int writeBlock = 4;

  int messageLen = 5 + path.length();
  char hdr[] = { 
    0x00, 0x00, 0x03, (char) messageLen, 0xd1, 0x01, (char) (path.length() + 1), 0x55, 0x01
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
    

    if (count == 16 || i == message.length - 1) {
      myReader.authenticate(writeBlock, 0xFF);
      delay(2000);
      println("[" + block + "], " + block.length());

      myReader.writeBlock(writeBlock, block);           

      int thisByte;
      for (int x = 0; x < 16; x++) {
        if (x < block.length()) {
          thisByte = (int)block.charAt(x);
          print("[" + thisByte + "]");
        } 
        else {
          thisByte = 0;
        }
      } 
      println("");


      writeBlock++;
      count = 0;
    }
  }
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


void printStatus() {

  println("Command: " + lastCommand);
  println("Packet Length: " + lastPacketLength);
  println("Antenna Power: " + lastAntennaPower);
  // print the hex values for all the bytes in the response:
  String responseString = "";
  if (lastResponse != null) {
    for (int b = 0; b < lastResponse.length; b++) {
      responseString += hex(lastResponse[b], 2) + " ";
    }
    // wrap the full text so it doesn't overflow the buttons
    // and make the screen all messy:
    println("Response: " + responseString);
  }
  // print any error messages from the reader:
  println("Error: " + myReader.getErrorMessage());
}
