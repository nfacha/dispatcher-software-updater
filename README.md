# Repository of the Original Open Source Puchisoft Dispatcher

![image](http://www.puchisoft.com/Dispatcher/Updater.png)

Dispatcher creates a fully functional Updater executable for you to include with your software. All you need is a website (HTTP, HTTPS, or FTP), and your users will be kept up to date. Dispatcher automatically generates binary patch data and uploads it to your website(s) whenever you release a new version.

When the Updater is run on a user's PC, your software will automatically be patched to its latest version! The Updater can be run in a variety of ways, including to only pop-up when an update is available. Deploying powerful Updaters has never been this simple!

Video Tutorial: [Make an Updater in under 5 Minutes!](http://www.puchisoft.com/Dispatcher/tutorial.htm)

Include an Updater with your software to keep it updated:


## Features
- Create Updaters and Installers for your software
- Choose Patch Mode (Transfers only the binary difference between files) or Sync Mode (Transfers compressed individual changed files)
- Release Updates via any standard Website (HTTP, HTTPS, or FTP)
- Supports downloading updates from multiple mirror Websites, if desired
- Works with Free Webhosts, thanks to File Extension Masking
- All data needed for the Updater to update your software is automatically generated and uploaded to your website for you
- Updater can be configured to only pop-up when there is an update available, to be run before your software, or to be manually run through your software
- Save bandwidth! Only 2 bytes are downloaded to check for updates; Patches can be as small as 200 bytes
- Small Updater file size (about 100kb)
- Change between using binary patches or downloading compressed individual files at any time
- File Recovery allows updating of files that were deleted/altered by the user, which would otherwise be unpatchable
- Automatic Rollback ensures that your software is never left in an unusable state due to interrupted updates
- Works fully without relying on any propietary servers
- Simple to set up and maintain using a GUI
- Optional Command-line parameters allow scripting the distribution of your software
- Runs on Windows 7, Windows Vista, Windows XP, and Wine(Linux)

## How it Works

Initially, release your software with a generated Updater. (See Step By Step for details)

Then, or whenever you release a new version, upload generated update data to your Update Mirror URLs (any webservers that allow downloading of files will work - even many free webhosts).

When the Updater is run, it will connect to the first mirror that it can, and download a tiny file (~2 bytes), which contains an integer representing the newest version.

What happens when a new version is found depends on what Mode you chose for the updater to use: 


## Patch Mode

Patch Mode Features
Usually best choice: Best Compression, Lowest Bandwidth
Only 7zip-compressed binary differences between versions are downloaded (Changed files are patched, new files/folders are included, removed files/folders are deleted)
Zero Overhead - Unlike stand-alone patches, the patching engine is only included in the Updater, so it is not necessary to re-downloaded on every patch (Patches can be as small as 200 bytes)
File Recovery - If a user deleted/altered a file that was to be patched, it will recover, by being downloaded whole - optionally 7zipped (this feature can be disabled)
To generate direct patches, all released old versions from which you want to create a direct patch to the newest version must be retained
Patch Chaining - You can choose to stop creating direct patches from certain old versions, which will then be updated with a combination of previously created patches and new patches (The benefit is that you don't need to keep the content of those old versions around)
When an update is found, the Updater will attempt to download the specific patch needed to update from its version to the new version. If found, the patch data is extracted and applied. This data includes which files to patch, which files/folders to add, and which files/folders to delete.

If no direct patch to the new version exists, the Updater will look up how to get to the newest version. This may be a chain of patches, file syncing (see below), or a combination of both.



## Sync Mode

Sync Mode Features
All new/altered files are downloaded whole (optionally 7zip compressed)
No need to retain old versions
When a new version is found, all files that exist in the newest version are inspected locally, and replaced if outdated/nonexistent
When an update is found, the Updater will download a snapshot of the newest version. This is a list of all files that exist in the newest version, along with their MD5 checksums.

The Updater will then go through the list, and check that all files on this list exist with the same MD5 checksum. If this is not the case for a file, the Updater will download the file (extracting it - if compressed).


## Note on Data Integrity

To ensure that your software is never left in a half-updated or otherwise unusable state, none of your software's files are ever altered until all required update data (patches or otherwise) has been successfully downloaded, and all files to be updated have been confirmed to be writable (not in use).

If the Updater is unable to update any part of your software, your entire software will be left exactly as it was before the update process began.


## Manual

Original link: [Manual](http://puchisoft.com/Dispatcher/Manual/)


## Original Download

Original download link in 7zip: [Source](http://www.puchisoft.com/PuchisoftWebsite.7z)


