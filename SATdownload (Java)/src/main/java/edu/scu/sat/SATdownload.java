/**
 * SATdownload
 * Copyright (C) 2015 Santa Clara University
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * For a copy of the GNU General Public License, v3.0, please refer to
 * <https://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 * Additional Terms:
 *   1. Santa Clara University reserves the right to refuse support of the
 *      software at any time.  We are not obligated to assist in documenting,
 *      debugging, customizing, testing or otherwise explaining or supporting
 *      the software.
 *   2. Your institution may share the software (or derivative work) only for
 *      educational or research purposes and must do so without charging any
 *      fees.  This requirement revokes the permission in section 4 to charge
 *      a fee for this or any derivative work.
 */
package edu.scu.sat;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.security.SecureRandom;
import java.security.cert.X509Certificate;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Properties;

import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSession;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

import org.codehaus.jettison.json.JSONException;
import org.codehaus.jettison.json.JSONObject;
import org.collegeboard.scoredwnld.client.FileInfo;

import com.sun.jersey.api.client.Client;
import com.sun.jersey.api.client.ClientHandlerException;
import com.sun.jersey.api.client.ClientResponse;
import com.sun.jersey.api.client.UniformInterfaceException;
import com.sun.jersey.api.client.WebResource;
import com.sun.jersey.api.client.config.ClientConfig;
import com.sun.jersey.api.client.config.DefaultClientConfig;
import com.sun.jersey.client.urlconnection.HTTPSProperties;

/**
 * <p>
 * This program will use the PAScoresDwnld API from CollegeBoard to download SAT
 * score files. This program has been designed so that it can run from the
 * command line in an automated fashion and keep track of the last file number
 * to successfully download.
 * </p>
 * 
 * <p>
 * In order to use this, a config file is needed (see
 * <code>config.properties</code>). At the very least, this file must specify
 * the username, password, orgID, and localFilePath.
 * </p>
 * 
 * <p>
 * At run-time, the following options may be set:
 * </p>
 * 
 * <pre>
 *  --config=CONFIGFILE 
 *    Specify the path and file name of the config file. Default is 
 *    config.properties.
 * 
 *  --date=DATE 
 *    Specify date of file to download. Default is today's date.  Recommended
 *    format is YYYYMMDD.
 * 
 *  --filenum=NUM
 *    Specify the job number to start searching from. This is the last part of 
 *    the file name. Default is the next number in the counter file.
 * 
 *  --filename=FILENAME 
 *    Specify the exact file name to download.
 * 
 *  -h | --help
 *    Display this help information.
 * </pre>
 *
 * <p>
 * NOTE: The development of this program was based on the sample provided by
 * CollegeBoard at: <a href=
 * "https://collegereadiness.collegeboard.org/zip/pascoredwnld-java-sample.zip">
 * https://collegereadiness.collegeboard.org/zip/pascoredwnld-java-sample.zip
 * </a>. The sample was accessed 2015-11-08.
 * </p>
 * 
 * <p>
 * Additional documentation on the functions provided by CollegeBoard may be
 * found at: <a href=
 * "https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#features">
 * https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-
 * portal-help#features</a>
 * </p>
 * 
 * <p>
 * Exit Codes:
 * </p>
 * <ul>
 * <li>0 - Success</li>
 * <li>1 - Unknown option</li>
 * <li>2 - Cannot find the config file</li>
 * <li>3 - Invalid date format</li>
 * <li>4 - Invalid file number</li>
 * </ul>
 * 
 * @author Brian Moon (bmoon@scu.edu)
 * @version 1.0
 * 
 */
public class SATdownload {

  /**
   * Possible Exit Codes that SATdownload can use.
   *
   * @author Brian Moon (bmoon@scu.edu)
   *
   */
  public static enum ExitStatus {
    /**
     * Invalid date given on the command line (3)
     */
    INVALID_DATE_FORMAT(3),
    /**
     * Invalid file number given on the command line (4)
     */
    INVALID_FILE_NUM(4),
    /**
     * Cannot find the configuration file (2)
     */
    MISSING_CONFIG_FILE(2),
    /**
     * Program success (0)
     */
    SUCCESS(0),
    /**
     * Unknown command line option (1)
     */
    UNKNOWN_OPTION(1);

    private final int code;

    private ExitStatus(int code) {
      this.code = code;
    }

    /**
     * Get the numeric value of the exit code
     * 
     * @return Numeric value of exit code
     */
    public int getCode() {
      return this.code;
    }
  }

  /**
   * Print a time-stamped log message on the console
   * 
   * @param msg Message to print
   */
  public static void log(String msg) {
    System.out
        .println(new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date())
            + ": " + msg);
  }

  /**
   * Main driver of the program. For a list of possible values in args, please
   * see {@link SATdownload}.
   * 
   * @param args Command line arguments
   */
  public static void main(String[] args) {
    // Print licensing information
    System.out
        .println("SATdownload  Copyright (C) 2015  Santa Clara University\n"
            + "This program comes with ABSOLUTELY NO WARRANTY.  This is free software, and you\n"
            + "are welcome to redistribute it under certain conditions.  For those conditions,\n"
            + "please refer to the License section in the header of this file.\n");

    // Initialize configuration options
    String configFile = null;
    String fileName = null;
    String fileNum = null;
    String date = null;
    boolean saveCounter = true;

    // Check command line options
    for (int i = 0; i < args.length; ++i) {
      // Look for a config file
      if (args[i].startsWith("--config="))
        configFile = removeQuotes(args[i].replaceFirst("--config=", ""));

      // Look for a specified file name to download
      else if (args[i].startsWith("--filename=")) {
        fileName = removeQuotes(args[i].replaceFirst("--filename=", ""));
        saveCounter = false;
      }
      // Look for a specified file number to start searching from
      else if (args[i].startsWith("--filenum=")) {
        fileNum = removeQuotes(args[i].replaceFirst("--filenum=", ""));
        saveCounter = false;
      }
      // Look for a specified date to search for files from
      else if (args[i].startsWith("--date="))
        date = removeQuotes(args[i].replaceFirst("--date=", ""));

      // Look to see if the user wants the help information
      else if (args[i].equalsIgnoreCase("--help") || args[i].equals("-h")) {
        printHelp();
        System.exit(ExitStatus.SUCCESS.getCode());
      }
      // Catch any unknown options
      else {
        System.out.println("Unknown option: " + args[i]);
        printHelp();
        System.exit(ExitStatus.UNKNOWN_OPTION.getCode());
      }
    }

    // If a configFile has not been specified yet, use config.properties
    if (configFile == null)
      configFile = "config.properties";

    // Create new SATdownload Object
    SATdownload sat = new SATdownload(configFile);
    sat.setSaveCounter(saveCounter);

    // Set date of file to download. Use today's date if a date was not
    // specified on the command line.
    SimpleDateFormat df = new SimpleDateFormat("yyyyMMdd");
    if (date == null) {
      sat.setDateString(df.format(new Date()));
    } else {
      try {
        sat.setDateString(df.format(df.parse(date)));
      } catch (ParseException e) {
        log("Invalid date specified: " + date);
        System.exit(ExitStatus.INVALID_DATE_FORMAT.getCode());
      }
    }

    // Set file counter if specified on the command line
    if (fileNum != null) {
      try {
        sat.setCounter(Integer.parseInt(fileNum));
      } catch (NumberFormatException e) {
        log("Invalid file number specified: " + fileNum);
        System.exit(ExitStatus.INVALID_FILE_NUM.getCode());
      }
    }

    // Set fileName. If not specified on the command line, generate the next
    // file name using getNextFileName().
    if (fileName == null)
      fileName = sat.getNextFileName();
    else
      sat.setDownloadConsecutiveFiles(false);

    // Download file(s)
    boolean successfulDownload = true;
    try {
      do {
        successfulDownload = sat.downloadFile(fileName);
        // If download is successful, prepare to download the next file
        if (sat.getCounter() > 1 && successfulDownload) {
          sat.writeCounterFile();
          sat.incrementCounter();
          fileName = sat.getNextFileName();
        }
      } while (sat.isDownloadConsecutiveFiles() && successfulDownload);
    } catch (RuntimeException e) {
      log(e.getMessage());
    }
    log("Done.");
  }

  /**
   * Pad number with zeroes to get the correct number of digits
   *
   * @param i Integer to pad
   * @param length Number of digits in padded string
   * @return Padded string
   */
  private static String padString(int i, int length) {
    return padString("" + i, length);
  }

  /**
   * Pad number with zeroes to get the correct number of digits
   *
   * @param str String to pad
   * @param length Number of digits in padded string
   * @return Padded string
   */
  private static String padString(String str, int length) {
    while (str.length() < length) {
      str = "0" + str;
    }
    return str;
  }

  /**
   * Print help information to the console
   */
  private static void printHelp() {
    System.out.println(
        "Usage: SATdownload [--config=CONFIGFILE --date=DATE | --filenum=NUM | --filename=FILENAME]\n\n"
            + "Options:\n" + " --config=CONFIGFILE\n"
            + "   Specify the path and file name of the config file.  Default is\n"
            + "   config.properties.\n\n" + " --date=DATE\n"
            + "   Specify date of file to download.  Default is today's date.\n"
            + "   Recommended format is YYYYMMDD.\n\n" + " --filenum=NUM\n"
            + "   Specify the job number to start searching from.  This is the last\n"
            + "   part of the file name.  Default is the next number in the counter\n"
            + "   file.\n\n" + " --filename=FILENAME\n"
            + "   Specify the exact file name to download.\n\n"
            + " -h | --help\n" + "   Display this help information.");
  }

  /**
   * Remove single (') and double (") quotes from a string
   * 
   * @param str String to clean
   * @return String without the quotes
   */
  private static String removeQuotes(String str) {
    return str.replace("'", "").replace("\"", "");
  }

  /**
   * File counter.
   */
  private int counter = -1;

  /**
   * File where the file counter is saved.
   */
  private String counterFile;

  /**
   * Date to download files from. Value must be in the format
   * <code>YYYYMMDD</code>.
   */
  private String dateString;

  /**
   * Whether the program should download consecutive files for a specific date
   * or not.
   */
  private boolean downloadConsecutiveFiles;

  /**
   * File extension of the SAT score file.
   */
  private String fileExtension;

  /**
   * Number of digits in the file number field of the file name.
   */
  private int fileNumPadding;

  /**
   * Local directory to save SAT score files.
   */
  private String localFilePath;

  /**
   * Organization ID with CollegeBoard. This is the first field in the file
   * name.
   */
  private String orgID;

  /**
   * Password to login with.
   */
  private String password;

  /**
   * Whether the counter should be saved or not.
   */
  private boolean saveCounter = true;

  /**
   * Root URL to download files from.
   */
  private String scoredwnldUrlRoot;

  /**
   * Username to login with.
   */
  private String username;

  /**
   * Create a new SATdownload object. Creation requires a valid config file.
   * 
   * @param configFile Full path to the configuration file
   */
  public SATdownload(String configFile) {
    this.loadConfig(configFile);
  }

  /**
   * <p>
   * Download a file from CollegeBoard's PAScoresDwnld web service. Only slight
   * modifications were made to this function (specifically the output and the
   * return value).
   * </p>
   * <p>
   * For more information, please see: <a href=
   * "https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#features">
   * https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-
   * portal-help#features</a>
   * </p>
   * <p>
   * Original code can be accessed at: <a href=
   * "https://collegereadiness.collegeboard.org/zip/pascoredwnld-java-sample.zip">
   * https://collegereadiness.collegeboard.org/zip/pascoredwnld-java-sample.zip
   * </a>
   * </p>
   * 
   * @author CollegeBoard
   * @param filePath Path of file to download
   * @param url URL to download file from
   * @return TRUE if file download was successful<br>
   *         FALSE if there was an error
   */
  private boolean download(String filePath, String url) {
    log("Downloading file: " + filePath);
    try {
      Client client = getClient();
      WebResource webResource = client.resource(url);
      InputStream inputStream = webResource.accept("application/octet-stream")
          .get(InputStream.class);
      if (inputStream == null) {
        throw new RuntimeException("Failed : HTTP error code : ");
      }

      String fileName = null; // response.headers['content-disposition'].split('filename=')[1];
      if (fileName == null) {
        fileName = filePath.substring(filePath.lastIndexOf("/") + 1);
      }

      FileOutputStream out = new FileOutputStream(localFilePath + fileName);
      byte[] buffer = new byte[2048];
      int size = inputStream.read(buffer);
      while (size > 0) {
        out.write(buffer, 0, size);
        size = inputStream.read(buffer);
      }
      out.close();
      inputStream.close();
      log("file downloaded to: " + localFilePath + fileName);
      return true;
    } catch (Exception e) {
      log("Error: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }

  /**
   * <p>
   * Download a file from CollegeBoard's PAScoresDwnld web service. Only slight
   * modifications were made to this function (specifically the output and the
   * return value).
   * </p>
   * <p>
   * For more information, please see: <a href=
   * "https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#features">
   * https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-
   * portal-help#features</a>
   * </p>
   * <p>
   * Original code can be accessed at: <a href=
   * "https://collegereadiness.collegeboard.org/zip/pascoredwnld-java-sample.zip">
   * https://collegereadiness.collegeboard.org/zip/pascoredwnld-java-sample.zip
   * </a>
   * </p>
   * 
   * @author CollegeBoard
   * @param filePath File to download
   * @return TRUE if file download was successful<br>
   *         FALSE if there was an error or could not find the file
   */
  public boolean downloadFile(String filePath) {
    log("Getting download token for " + filePath);
    FileInfo fileInfo = null;
    String token = login(username, password);
    if ((token != null) && !token.isEmpty()) {
      fileInfo = getFileUrlByToken(token, filePath);
    }

    if (fileInfo != null) {
      return download(fileInfo.getFileName(), fileInfo.getFileUrl());
    }
    return false;
  }

  /**
   * <p>
   * Create the JerseyClient to be used when downloading a file. This has not
   * been modified from the original version.
   * </p>
   * <p>
   * For more information, please see: <a href=
   * "https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#features">
   * https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-
   * portal-help#features</a>
   * </p>
   * <p>
   * Original code can be accessed at: <a href=
   * "https://collegereadiness.collegeboard.org/zip/pascoredwnld-java-sample.zip">
   * https://collegereadiness.collegeboard.org/zip/pascoredwnld-java-sample.zip
   * </a>
   * </p>
   * 
   * @author CollegeBoard
   * @return Configured JerseyClient
   */
  protected Client getClient() {
    Client jerseyClient = null;
    SSLContext sslContext = this.getSslContextAcceptsBadCerts();

    // Set up a hostname verifier that ignores invalid hostnames
    HostnameVerifier hostnameVerifier = new HostnameVerifier() {
      @Override
      public boolean verify(String hostname, SSLSession sslSession) {
        return true;
      }
    };

    ClientConfig jerseyClientConfig = new DefaultClientConfig();
    jerseyClientConfig.getProperties().put(
        HTTPSProperties.PROPERTY_HTTPS_PROPERTIES,
        new HTTPSProperties(hostnameVerifier, sslContext));

    jerseyClient = Client.create(jerseyClientConfig);

    return jerseyClient;
  }

  /**
   * Get the file number counter
   * 
   * @return the counter
   */
  public int getCounter() {
    return counter;
  }

  /**
   * Get the counter file name
   * 
   * @return the counterFile
   */
  public String getCounterFile() {
    return counterFile;
  }

  /**
   * Get the date string (formatted <code>YYYYMMDD</code>) for the files to
   * download
   * 
   * @return the dateString Date string (formatted <code>YYYYMMDD</code>) for
   *         the files to download
   */
  public String getDateString() {
    return dateString;
  }

  /**
   * Get the file extension of the SAT score file
   * 
   * @return the fileExtension
   */
  public String getFileExtension() {
    return fileExtension;
  }

  /**
   * Get the number of digits that should be used in the file number field of
   * the file name
   * 
   * @return the fileNumPadding Number of digits in the file number field
   */
  public int getFileNumPadding() {
    return fileNumPadding;
  }

  /**
   * <p>
   * Get the URL of the file to download. This has not been modified from the
   * original version.
   * </p>
   * <p>
   * For more information, please see: <a href=
   * "https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#features">
   * https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-
   * portal-help#features</a>
   * </p>
   * <p>
   * Original code can be accessed at: <a href=
   * "https://collegereadiness.collegeboard.org/zip/pascoredwnld-java-sample.zip">
   * https://collegereadiness.collegeboard.org/zip/pascoredwnld-java-sample.zip
   * </a>
   * </p>
   * 
   * @see #login(String, String)
   * @see org.collegeboard.scoredwnld.client.FileInfo
   * @author CollegeBoard
   * @param accessToken Access token obtained from
   *          {@link #login(String, String)}
   * @param filePath File to download
   * @return FileInfo descriptor of file to download
   */
  private FileInfo getFileUrlByToken(String accessToken, String filePath) {

    Client client = getClient();
    WebResource webResource = client.resource(scoredwnldUrlRoot
        + "/pascoredwnld/file?tok=" + accessToken + "&filename=" + filePath);
    ClientResponse response = webResource.accept("application/json")
        .get(ClientResponse.class);
    if (response.getStatus() != 200) {
      throw new RuntimeException(
          "Failed : HTTP error code : " + response.getStatus());
    }

    try {
      JSONObject json = new JSONObject(response.getEntity(String.class));
      FileInfo fileInfo = new FileInfo();
      fileInfo.setFileName(filePath);
      fileInfo.setFileUrl(String.valueOf(json.get("fileUrl")));
      return fileInfo;
    } catch (ClientHandlerException e) {
      log("Error: " + e.getMessage());
      e.printStackTrace();
    } catch (UniformInterfaceException e) {
      log("Error: " + e.getMessage());
      e.printStackTrace();
    } catch (JSONException e) {
      log("Error: " + e.getMessage());
      e.printStackTrace();
    }

    return null;
  }

  /**
   * Get local file path to download files to
   * 
   * @return the localFilePath
   */
  public String getLocalFilePath() {
    return localFilePath;
  }

  /**
   * <p>
   * Generate the name of the next file in the sequence to download. If counter
   * has not been set, then the counter will be read from the counter file.
   * </p>
   * <p>
   * File name is in the format: <code>ORGID_YYYYMMDD_FILENUM.txt</code>.
   * </p>
   * 
   * @return File name
   */
  public String getNextFileName() {
    // If counter does not have a valid value, read in the value from the
    // counter file.
    if (this.counter < 0) {
      try {
        BufferedReader buf = new BufferedReader(
            new FileReader(this.counterFile));
        String line = buf.readLine();
        buf.close();
        this.setCounter(Integer.parseInt(line) + 1);
      } catch (NumberFormatException e) {
        log("Invalid number in counter file " + this.counterFile);
      } catch (FileNotFoundException e) {
        log("Could not find counter file " + this.counterFile);
      } catch (IOException e) {
        log("Error reading counter file " + this.counterFile);
        e.printStackTrace();
      } finally {
        if (this.counter < 1) {
          log("Using default counter value of 1");
          this.setCounter(1);
        }
      }
    }

    // Return name of next file to download
    return this.orgID + "_" + this.dateString + "_"
        + padString(this.counter, this.fileNumPadding) + "."
        + this.fileExtension;
  }

  /**
   * Get the organization ID
   * 
   * @return the orgID
   */
  public String getOrgID() {
    return orgID;
  }

  /**
   * Get the SAT score download root URL
   * 
   * @return the scoredwnldUrlRoot
   */
  public String getScoredwnldUrlRoot() {
    return scoredwnldUrlRoot;
  }

  /**
   * <p>
   * Create a SSLContext with a TrustManager that will accept all certificates.
   * This method has not been modified from the original published by
   * CollegeBoard.
   * </p>
   * <p>
   * For more information, please see: <a href=
   * "https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#features">
   * https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-
   * portal-help#features</a>
   * </p>
   * <p>
   * Original code can be accessed at: <a href=
   * "https://collegereadiness.collegeboard.org/zip/pascoredwnld-java-sample.zip">
   * https://collegereadiness.collegeboard.org/zip/pascoredwnld-java-sample.zip
   * </a>
   * </p>
   * 
   * @see SSLContext
   * @author CollegeBoard
   * @return SSLContext that will trust any certificate
   */
  private SSLContext getSslContextAcceptsBadCerts() {
    SSLContext sslContext = null;
    try {
      sslContext = SSLContext.getInstance("SSL");

      // set up a TrustManager that trusts everything
      sslContext.init(null, new TrustManager[] { new X509TrustManager() {
        X509Certificate[] certificates = null;

        @Override
        public void checkClientTrusted(X509Certificate[] certs, String authType)// NOPMD
        {
        }

        @Override
        public void checkServerTrusted(X509Certificate[] certs, String authType)// NOPMD
        {
        }

        @Override
        public X509Certificate[] getAcceptedIssuers() {
          return certificates;
        }

      } }, new SecureRandom());
    } catch (Exception ex) {
      throw new RuntimeException("Problem getting ssl context", ex); // NOPMD
    }

    return sslContext;
  }

  /**
   * Get the username used to access the PAScoresDwnld site
   * 
   * @return the username
   */
  public String getUsername() {
    return username;
  }

  /**
   * Increment the file number counter by 1
   */
  public void incrementCounter() {
    this.counter = this.counter + 1;
  }

  /**
   * Determine if the program should attempt to download consecutive files from
   * the specified date
   * 
   * @return TRUE if the program should download consecutive files<br>
   *         FALSE if the program should download a single file
   */
  public boolean isDownloadConsecutiveFiles() {
    return downloadConsecutiveFiles;
  }

  /**
   * Determine whether the file number should be written to the counter file
   * 
   * @return TRUE if the file number SHOULD be saved<br>
   *         FALSE if the file number SHOULD NOT be saved
   */
  public boolean isSaveCounter() {
    return saveCounter;
  }

  /**
   * <p>
   * Load the configuration file. Supported configuration options are:
   * </p>
   * <ul>
   * <li>localFilePath</li>
   * <li>scoredwnldUrlRoot</li>
   * <li>username</li>
   * <li>password</li>
   * <li>orgID</li>
   * <li>fileExtension</li>
   * <li>downloadConsecutiveFiles</li>
   * <li>counterFile</li>
   * <li>fileNumPadding</li>
   * </ul>
   * <p>
   * For a description of these, please refer to the sample
   * <code>config.properties</code>.
   * </p>
   * 
   * @param fileName Full path to the configuration file
   */
  public void loadConfig(String fileName) {
    log("Loading config file " + fileName);
    Properties config = new Properties();

    // Attempt to open the configuration file and populate config
    try {
      InputStream configFileIS = new FileInputStream(fileName);
      config.load(configFileIS);
    } catch (FileNotFoundException e) {
      log("Count not find config file " + fileName);
      System.exit(ExitStatus.MISSING_CONFIG_FILE.getCode());
    } catch (IOException e) {
      log("Error reading config file " + fileName);
      e.printStackTrace();
    }

    // ---------------------------------------------------------------------
    // Setup this SATdownload object with the options set in the config file
    // ---------------------------------------------------------------------

    // Set the counter file
    this.setCounterFile(
        removeQuotes(config.getProperty("counterFile", "SATdownload.counter")));

    // Set if this should attempt to download consecutive files
    this.setDownloadConsecutiveFiles(Boolean.parseBoolean(
        removeQuotes(config.getProperty("downloadConsecutiveFiles", "true"))));

    // Set the file extension
    this.setFileExtension(
        removeQuotes(config.getProperty("fileExtension", "txt")));

    // Set the number of digits in the file number field of the file name
    this.setFileNumPadding(Integer
        .parseInt(removeQuotes(config.getProperty("fileNumPadding", "6"))));

    // Set the local directory to download SAT score files
    this.setLocalFilePath(removeQuotes(config.getProperty("localFilePath")));

    // Set the organization ID
    this.setOrgID(removeQuotes(config.getProperty("orgID")));

    // Set the password to login with
    this.setPassword(removeQuotes(config.getProperty("password")));

    // Set the root URL of the scores download site
    this.setScoredwnldUrlRoot(removeQuotes(config.getProperty(
        "scoredwnldUrlRoot", "https://scoresdownload.collegeboard.org")));

    // Set the username to login with
    this.setUsername(removeQuotes(config.getProperty("username")));
  }

  /**
   * <p>
   * Login to the PAScoresDwnld site. This method has not been modified from the
   * original published by CollegeBoard.
   * </p>
   * <p>
   * For more information, please see: <a href=
   * "https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#features">
   * https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-
   * portal-help#features</a>
   * </p>
   * <p>
   * Original code can be accessed at: <a href=
   * "https://collegereadiness.collegeboard.org/zip/pascoredwnld-java-sample.zip">
   * https://collegereadiness.collegeboard.org/zip/pascoredwnld-java-sample.zip
   * </a>
   * </p>
   * 
   * @author CollegeBoard
   * @param username Username to login with
   * @param password Password to login with
   * @return Authentication token
   */
  private String login(String username, String password) {
    Client client = getClient();
    WebResource webResource = client
        .resource(scoredwnldUrlRoot + "/pascoredwnld/login");

    String input = "{\"username\":\"" + username + "\",\"password\":\""
        + password + "\"};";

    ClientResponse response = webResource.accept("application/json")
        .type("application/json").post(ClientResponse.class, input);

    if (response.getStatus() != 200) {
      throw new RuntimeException(
          "Failed : HTTP error code : " + response.getStatus());
    }

    try {
      JSONObject json = new JSONObject(response.getEntity(String.class));
      return String.valueOf(json.get("token"));
    } catch (Exception e) {
      log("Error: " + e.getMessage());
      e.printStackTrace();
    }
    return "";
  }

  /**
   * Set the file counter
   * 
   * @param counter the counter to set
   */
  public void setCounter(int counter) {
    this.counter = counter;
  }

  /**
   * Set the full path to the counter file
   * 
   * @param counterFile the counterFile to set
   */
  public void setCounterFile(String counterFile) {
    this.counterFile = counterFile;
  }

  /**
   * Set the date string to download files from. This should be in the format
   * <code>YYYYMMDD</code>.
   * 
   * @param dateString the dateString to set
   */
  public void setDateString(String dateString) {
    this.dateString = dateString;
  }

  /**
   * Set whether this program should attempt to download consecutive files for a
   * specified date.
   * 
   * @param downloadConsecutiveFiles the downloadConsecutiveFiles to set
   */
  public void setDownloadConsecutiveFiles(boolean downloadConsecutiveFiles) {
    this.downloadConsecutiveFiles = downloadConsecutiveFiles;
  }

  /**
   * Set the file extension of the SAT score file
   * 
   * @param fileExtension the fileExtension to set
   */
  public void setFileExtension(String fileExtension) {
    if (fileExtension.charAt(0) == '.')
      this.fileExtension = fileExtension.substring(1);
    else
      this.fileExtension = fileExtension;
  }

  /**
   * Set the number of digits that should be in the file number field of the
   * file name.
   * 
   * @param fileNumPadding the fileNumPadding to set
   */
  public void setFileNumPadding(int fileNumPadding) {
    this.fileNumPadding = fileNumPadding;
  }

  /**
   * Set the local path to download SAT score files.
   * 
   * @param localFilePath the setLocalFilePath to set
   */
  public void setLocalFilePath(String localFilePath) {
    if (localFilePath.charAt(localFilePath.length() - 1) != File.separatorChar)
      this.localFilePath = localFilePath + File.separatorChar;
    else
      this.localFilePath = localFilePath;
  }

  /**
   * Set the organization ID.
   * 
   * @param orgID the orgID to set
   */
  public void setOrgID(String orgID) {
    this.orgID = orgID;
  }

  /**
   * Set the password used to access the PAScoresDwnld site
   * 
   * @param password the password to set
   */
  public void setPassword(String password) {
    this.password = password;
  }

  /**
   * @param saveCounter the saveCounter to set
   */
  public void setSaveCounter(boolean saveCounter) {
    this.saveCounter = saveCounter;
  }

  /**
   * Set the SAT score download root URL
   * 
   * @param scoredwnldUrlRoot Root URL
   */
  public void setScoredwnldUrlRoot(String scoredwnldUrlRoot) {
    this.scoredwnldUrlRoot = scoredwnldUrlRoot;
  }

  /**
   * Set the username used to access the PAScoresDwnld site
   * 
   * @param username the username to set
   */
  public void setUsername(String username) {
    this.username = username;
  }

  /**
   * Write the current value of the file counter to the counter file
   * 
   * @return TRUE if successfully saved to the counter file<br>
   *         FALSE if either there was an error or if saveCounter is FALSE
   */
  public boolean writeCounterFile() {
    if (this.isSaveCounter()) {
      try {
        BufferedWriter counterFile = new BufferedWriter(
            new FileWriter(this.getCounterFile(), false));
        counterFile.write("" + getCounter() + "\n");
        counterFile.close();
        return true;
      } catch (IOException e) {
        log("Error writing to counter file " + this.getCounterFile());
        return false;
      }
    } else
      return false;
  }
}
