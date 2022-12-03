![GitHub last commit](https://img.shields.io/github/last-commit/yakisyst3m/ramParserVolatility3) 
![GitHub release-date](https://img.shields.io/github/release-date/yakisyst3m/ramParserVolatility3)
#  ramParserVolatility 3
This application searches RAM memories from a folder.
Steps after launch:
- Pre-requisite test
- Install csv2xlsx if it does not exist
- Test internet connection + Installation of Volatility 3 if it does not exist
- Parsing of each RAM image
- Obtaining CSV files / 1 file per plugin
- Conversion of CSV files to XLSX

# Prepare :
chmod +x ramParserVolatility3.sh

# Using :
./ramParserVolatility3.sh -d 'folder containing RAM images'
