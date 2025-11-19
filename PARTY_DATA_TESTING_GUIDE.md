# Party Data Testing Guide

## Overview
This guide helps verify that party data (description, address, time, ticket link) is now displaying correctly in the app after the Firebase parser improvements.

## What Was Fixed

### 1. Enhanced Field Name Parsing
The parser now checks multiple field name variations for:
- **Description**: `description`, `desc`, `details`, `about`, `info`
- **Address**: `address`, `location`, `venue`, `place`, `where`
- **Ticket URL**: `URL`, `ticketURL`, `ticketUrl`, `link`, `ticketLink`, `eventLink`, `url`
- **Date/Time**: `dateTime`, `date`, `time`, `startTime`, `eventDate`, `start`
- **Host Name**: `hostName`, `host_name`, `groupName`, `group_name`, `organization`, `org`, `host`, `organizer`

### 2. Improved Date Parsing
Added support for many date/time formats:
- ISO 8601 formats (e.g., `2025-11-15T20:00:00Z`)
- Unix timestamps (seconds and milliseconds)
- Natural language (e.g., `November 15, 2025 at 9:00 PM`)
- Various numeric formats (e.g., `11/15/2025`)
- Date extraction from description text using regex patterns

### 3. Comprehensive Debug Logging
Every party document now logs:
- Document ID
- All available field names
- Parsed values for each field
- Date parsing attempts and results

## How to Test

### Step 1: Run the App
1. Open the Crowd app in Xcode
2. Build and run on a simulator or device
3. Navigate to the Calendar view
4. Tap on the "Parties" tab

### Step 2: Check Console Output
Look for debug logs in the Xcode console:

```
🎉 Starting party fetch...
📊 Found X documents in events_from_linktree_raw
📄 Document ID: [document-id]
📄 Document data keys: [array of field names]
📄 Parsing party document: [document-id]
📄 Available fields: [array of field names]
📄 Description: [description preview or "empty"]
📄 Address: [address or "nil"]
📄 Image URL: [URL or "nil"]
📄 Ticket URL: [URL or "nil"]
📄 Host Name: [host name]
📄 Found dateTime string: [date string]
📄 Final parsed date: [parsed date or "nil"]
✅ Successfully fetched X parties
```

### Step 3: Verify Party Cards Display
Each party card should show:
- ✅ **Title**: Party name (always required)
- ✅ **Host Name**: Below title (if available)
- ✅ **Time**: With 📅 emoji (e.g., "Nov 23 at 9:00 PM")
- ✅ **Address**: With 📍 emoji (e.g., "123 Main St")
- ✅ **Going Count**: "X going" (if > 0)
- ✅ **Buy Ticket Button**: Black button (if ticket URL exists)

### Step 4: Test Party Detail View
Tap on a party card to open the detail view:
- ✅ **Full Description**: Shows complete description text
- ✅ **Date & Time Section**: Formatted nicely with calendar icon
- ✅ **Location Section**: Clickable with arrow icon
- ✅ **Buy Tickets Button**: Opens ticket URL in browser
- ✅ **I'm Going Button**: Allows marking attendance

### Step 5: Test Address Maps Integration
1. Tap on a party card detail view
2. Tap on the location/address section (with arrow icon)
3. ✅ Verify Apple Maps opens with the location
4. ✅ Verify directions are available

## Troubleshooting

### If Data Is Still Missing

#### Check Console Logs
Look for these specific log messages:
- `"📄 Description: empty"` → Description field not found or empty in Firebase
- `"📄 Address: nil"` → Address field not found in Firebase
- `"📄 Ticket URL: nil"` → Ticket URL field not found in Firebase
- `"⚠️ Could not parse date string"` → Date format not recognized

#### Identify Field Names
The console shows all available fields:
```
📄 Available fields: ["field1", "field2", "field3", ...]
```

Compare these with the field names being checked in the code. If Firebase uses different field names, they need to be added to the parser.

#### Common Firebase Field Name Issues
- Field names might be capitalized differently (e.g., `Address` vs `address`)
- Field names might use different separators (e.g., `event_date` vs `eventDate`)
- Field names might be abbreviated (e.g., `desc` vs `description`)

### If Dates Are Not Parsing
Check the console for:
```
📄 Found dateTime string: [the actual string]
⚠️ Could not parse date string: [the actual string]
```

If a date format is not recognized, add it to `parseDateTimeString()` function.

### If Address Doesn't Open Maps
- Verify the address string is valid
- Check that coordinates are being set (default: UNT campus)
- Ensure location permissions are granted

## Expected Firebase Data Structure

The parser expects data from `events_from_linktree_raw` collection with fields like:
```json
{
  "title": "Party Name",
  "description": "Full party description...",
  "address": "123 Main Street, City, State",
  "URL": "https://ticketsite.com/event",
  "dateTime": "2025-11-23T21:00:00Z",
  "uploadedImageUrl": "https://image.url/photo.jpg",
  "hostName": "Party Host Name"
}
```

## Next Steps

### If Everything Works
1. Mark all tests as passed
2. Close this testing document
3. Enjoy the party feature! 🎉

### If Issues Persist
1. Copy relevant console logs
2. Check Firebase console for actual field names
3. Update the parser with correct field name variations
4. Re-run tests

## Summary Checklist

- [ ] App builds and runs without errors
- [ ] Parties load in the Calendar > Parties tab
- [ ] Party cards show title, host, time, address
- [ ] Buy Ticket button appears (if URL exists)
- [ ] Tapping card opens detail view
- [ ] Description displays in detail view
- [ ] Time shows formatted correctly
- [ ] Address is clickable and opens Maps
- [ ] Buy Tickets button opens URL in browser
- [ ] Console logs show successful parsing
- [ ] No error messages in console

