// Unit1.pas - Main form for IP Geolocation application
// This application uses MaxMind's GeoIP database to look up country information for IP addresses

unit Unit1;

interface

uses
  // Windows API and standard VCL components
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Imaging.pngimage,
  Vcl.Imaging.jpeg,
  // Custom MaxMind DB reader components
  uMMDBReader, uMMDBInfo, uMMDBIPAddress,
  // Additional system utilities
  System.StrUtils, System.Generics.Collections, Vcl.ComCtrls;

type
  // Main form class
  TForm1 = class(TForm)
    // UI Components
    EditIP: TEdit;                // Input field for IP address
    LabelIP: TLabel;              // Label for IP input
    ButtonLookup: TButton;        // Button to trigger IP lookup
    PanelResult: TPanel;          // Panel to display results
    ImageFlag: TImage;            // Image component to display country flag
    LabelCountry: TLabel;         // Label to display country name
    OpenDialog1: TOpenDialog;     // Dialog for opening database files
    ButtonOpenDB: TButton;        // Button to open database file
    StatusBar1: TStatusBar;       // Status bar for application messages

    // Event handlers
    procedure FormCreate(Sender: TObject);      // Called when form is created
    procedure ButtonLookupClick(Sender: TObject); // Called when lookup button is clicked
    procedure FormDestroy(Sender: TObject);     // Called when form is destroyed
    procedure ButtonOpenDBClick(Sender: TObject); // Called when open DB button is clicked

  private
    // Private fields and methods
    FMMDBReader: TMMDBReader;     // MaxMind database reader instance
    FDatabaseLoaded: Boolean;     // Tracks if a database has been loaded
    FlagPath: string;             // Path to country flag images

    // Helper methods
    procedure LoadFlag(const CountryCode: string); // Loads country flag from file
    procedure LookupIP(const IPString: string);    // Looks up IP information

  public
    // Public declarations (none used in this form)
  end;

var
  // Global form variable
  Form1: TForm1;

implementation

// Links the form with its design file
{$R *.dfm}

// Form initialization
procedure TForm1.FormCreate(Sender: TObject);
begin
  // Initialize state variables
  FDatabaseLoaded := False;
  // Set path to flags directory (relative to executable)
  FlagPath := ExtractFilePath(Application.ExeName) + 'Flags\';
  // Set initial status message
  StatusBar1.SimpleText := 'Please load a MaxMind DB file';
end;

// Form cleanup
procedure TForm1.FormDestroy(Sender: TObject);
begin
  // Free MaxMind reader object if it exists
  if Assigned(FMMDBReader) then
    FreeAndNil(FMMDBReader);
end;

// Database file selection
procedure TForm1.ButtonOpenDBClick(Sender: TObject);
begin
  // Show file open dialog
  if OpenDialog1.Execute then
  begin
    // Free previous reader if it exists
    if Assigned(FMMDBReader) then
      FreeAndNil(FMMDBReader);

    try
      // Create new reader with selected file
      FMMDBReader := TMMDBReader.Create(OpenDialog1.FileName);
      FDatabaseLoaded := True;
      // Update status with loaded database filename
      StatusBar1.SimpleText := 'Database loaded: ' + ExtractFileName(OpenDialog1.FileName);
      // Enable lookup button now that database is loaded
      ButtonLookup.Enabled := True;
    except
      // Handle exceptions during database loading
      on E: Exception do
      begin
        StatusBar1.SimpleText := 'Error loading database: ' + E.Message;
        FDatabaseLoaded := False;
        ButtonLookup.Enabled := False;
      end;
    end;
  end;
end;

// IP lookup button click handler
procedure TForm1.ButtonLookupClick(Sender: TObject);
begin
  // Check if database is loaded before proceeding
  if not FDatabaseLoaded then
  begin
    ShowMessage('Please load a MaxMind DB file first');
    Exit;
  end;

  // Call IP lookup method with text from input field
  LookupIP(EditIP.Text);
end;

// Main IP lookup functionality
procedure TForm1.LookupIP(const IPString: string);
var
  ipAddress: TMMDBIPAddress;         // Parsed IP address object
  prefixLength: Integer;             // Network prefix length (not used here)
  ipCountryInfo: TMMDBIPCountryInfoEx; // Country info container
  ipCityInfo: TMMDBIPCountryCityInfoEx; // City info container
  countryCode: string;               // ISO country code
  countryName: string;               // Human-readable country name
  ipInfoFound: Boolean;              // Flag indicating if info was found
  dbType: string;                    // Type of the loaded MaxMind database
begin
  try
    // Parse IP address string into IP address object
    ipAddress := TMMDBIPAddress.Parse(IPString);
  except
    // Handle invalid IP address format
    on E: Exception do
    begin
      ShowMessage('Invalid IP address: ' + E.Message);
      Exit;
    end;
  end;

  // Create info containers
  ipCountryInfo := TMMDBIPCountryInfoEx.Create;
  ipCityInfo := TMMDBIPCountryCityInfoEx.Create;

  try
    // Get database type from metadata
    dbType := FMMDBReader.Metadata.DatabaseType;

    // Handle different database types differently
    if EndsStr('-city', dbType) then
    begin
      // City database contains additional location info
      ipInfoFound := FMMDBReader.Find<TMMDBIPCountryCityInfoEx>(ipAddress, prefixLength, ipCityInfo);
      if ipInfoFound then
      begin
        countryCode := ipCityInfo.Country.ISOCode;
        // Try to get English country name, fallback to code if not available
        if not ipCityInfo.Country.Names.TryGetValue('en', countryName) then
          countryName := countryCode;
      end;
    end
    else if not (EndsStr('-domain', dbType) or
                EndsStr('-anonymous-ip', dbType) or
                EndsStr('-isp', dbType) or
                EndsStr('-asn', dbType)) then
    begin
      // Country database or other database with country info
      ipInfoFound := FMMDBReader.Find<TMMDBIPCountryInfoEx>(ipAddress, prefixLength, ipCountryInfo);
      if ipInfoFound then
      begin
        countryCode := ipCountryInfo.Country.ISOCode;
        // Try to get English country name, fallback to code if not available
        if not ipCountryInfo.Country.Names.TryGetValue('en', countryName) then
          countryName := countryCode;
      end;
    end
    else
    begin
      // Database doesn't contain country information
      ShowMessage('This database type does not contain country information');
      Exit;
    end;

    // Display results if country information was found
    if ipInfoFound and (countryCode <> '') then
    begin
      // Set country label with name and code
      LabelCountry.Caption := Format('%s (%s)', [countryName, countryCode]);
      // Try to load country flag
      LoadFlag(countryCode);
      // Show results panel
      PanelResult.Visible := True;
    end
    else
    begin
      // No country information found for this IP
      ShowMessage('Country information not found for IP: ' + IPString);
      PanelResult.Visible := False;
    end;

  finally
    // Free info containers
    ipCityInfo.Free;
    ipCountryInfo.Free;
  end;
end;

// Loads flag image for a country
procedure TForm1.LoadFlag(const CountryCode: string);
var
  flagFilePNG: string;  // Path to potential PNG flag file
  flagFileJPG: string;  // Path to potential JPG flag file
  flagFileSVG: string;  // Path to potential SVG flag file
begin
  // Build paths for different flag file formats
  flagFilePNG := FlagPath + UpperCase(CountryCode) + '.png';
  flagFileJPG := FlagPath + UpperCase(CountryCode) + '.jpg';
  flagFileSVG := FlagPath + UpperCase(CountryCode) + '.svg';

  // Try to load PNG flag first
  if FileExists(flagFilePNG) then
  begin
    try
      ImageFlag.Picture.LoadFromFile(flagFilePNG);
      ImageFlag.Visible := True;
      StatusBar1.SimpleText := 'Found country: ' + CountryCode;
    except
      // Handle errors loading the image
      on E: Exception do
      begin
        ImageFlag.Visible := False;
        StatusBar1.SimpleText := 'Error loading flag: ' + E.Message;
      end;
    end;
  end
  // If PNG doesn't exist, try JPG
  else if FileExists(flagFileJPG) then
  begin
    try
      ImageFlag.Picture.LoadFromFile(flagFileJPG);
      ImageFlag.Visible := True;
      StatusBar1.SimpleText := 'Found country: ' + CountryCode;
    except
      // Handle errors loading the image
      on E: Exception do
      begin
        ImageFlag.Visible := False;
        StatusBar1.SimpleText := 'Error loading flag: ' + E.Message;
      end;
    end;
  end
  // Check if SVG exists but can't be displayed
  else if FileExists(flagFileSVG) then
  begin
    // SVG exists but we can't directly load it with standard VCL
    ImageFlag.Picture := nil;
    ImageFlag.Visible := False;
    StatusBar1.SimpleText := 'SVG flag found but cannot be displayed. Please convert to PNG.';
  end
  // No flag file found
  else
  begin
    ImageFlag.Picture := nil;
    ImageFlag.Visible := False;
    StatusBar1.SimpleText := 'Flag not found for country code: ' + CountryCode;
  end;
end;

end.
