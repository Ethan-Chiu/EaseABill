# Receipt Scanner & OCR Integration

This document describes the receipt scanning and OCR processing functionality in the EaseABill app.

## Overview

The receipt scanner allows users to:
1. **Capture receipts** using device camera
2. **Select from gallery** for existing images
3. **Upload to server** for OCR processing
4. **Auto-fill expense details** from extracted data

## Components

### 1. Camera Scanner Screen
**File**: `lib/screens/camera_scanner_screen.dart`

Provides an interface to capture or select receipt images with preview and confirmation.

**Features**:
- Camera capture using device camera
- Gallery picker for existing images
- Image preview with retake option
- Confirmation before upload

**Usage**:
```dart
final imagePath = await Navigator.of(context).push<String>(
  MaterialPageRoute(builder: (context) => const CameraScannerScreen()),
);
```

### 2. API Client Integration
**File**: `lib/data/client.dart`

The `uploadReceiptImage()` method handles multipart file uploads to the server.

**Endpoint**: `POST /api/ocr/process-receipt`

**Parameters**:
- `receipt` (file): The receipt image file
- `expenseId` (optional): Associate with existing expense

**Response**:
```json
{
  "success": true,
  "extractedData": {
    "merchant": "Store Name",
    "amount": 29.99,
    "date": "2026-02-07",
    "items": ["Item 1", "Item 2"],
    "tax": 2.40,
    "subtotal": 27.59,
    "receiptNumber": "12345"
  },
  "rawData": { /* Raw OCR output */ }
}
```

### 3. OCR Result Model
**File**: `lib/data/model/ocr_result.dart`

Represents structured OCR extraction results.

**Properties**:
- `merchant`: Store/vendor name
- `amount`: Total amount
- `date`: Transaction date
- `items`: List of purchased items
- `tax`: Tax amount
- `subtotal`: Amount before tax
- `receiptNumber`: Receipt ID
- `rawData`: Complete OCR data

### 4. Service Layer
**File**: `lib/data/service/expense_service.dart`

The `uploadReceiptImage()` method integrates receipt upload with the service layer.

## Implementation Details

### Adding Receipt to Expense

In `add_expense_screen.dart`, the receipt scanner is launched with:

```dart
Future<void> _launchCameraScanner() async {
  final imagePath = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (context) => const CameraScannerScreen()),
  );
  
  if (imagePath != null) {
    await _uploadReceiptImage(imagePath);
  }
}
```

### Handling OCR Results

After successful upload, the app automatically:

1. **Displays confirmation** of successful upload
2. **Pre-fills form fields** if data is available:
   - Amount field
   - Merchant/Title field
   - Date (if different from current)
3. **Stores reference** to uploaded receipt

```dart
if (result['extractedData'] != null) {
  final data = result['extractedData'];
  if (data['amount'] != null) {
    _amountController.text = data['amount'].toString();
  }
  if (data['merchant'] != null) {
    _titleController.text = data['merchant'];
  }
}
```

## Server Setup

Your backend should implement the following endpoint:

### POST `/api/ocr/process-receipt`

**Expected**:
- Multipart form data with receipt image
- Optional expenseId parameter

**Should Perform**:
1. Receive and store receipt image
2. Run OCR processing (using Tesseract, Azure Vision, Google Vision API, etc.)
3. Extract receipt data
4. Return structured JSON response

**Example Node.js/Express Implementation**:

```javascript
const multer = require('multer');
const Tesseract = require('tesseract.js');

router.post('/ocr/process-receipt', multer().single('receipt'), async (req, res) => {
  try {
    // Process image with OCR
    const { data: { text } } = await Tesseract.recognize(
      req.file.buffer,
      'eng'
    );
    
    // Parse extracted text to structured data
    const extracted = parseReceiptText(text);
    
    res.json({
      success: true,
      extractedData: {
        merchant: extracted.merchant,
        amount: extracted.amount,
        date: extracted.date,
        items: extracted.items,
        tax: extracted.tax,
        subtotal: extracted.subtotal,
        receiptNumber: extracted.receiptNumber
      },
      rawData: { ocrText: text }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to process receipt',
      error: error.message
    });
  }
});
```

## Usage Flow

### For Users

1. **In Add Expense Screen**
   - Tap "Scan Receipt" button
   
2. **In Camera Scanner**
   - Choose "Take Photo" or "Choose from Gallery"
   - Review captured image
   - Tap "Send" to upload
   
3. **Auto-fill**
   - App receives OCR results
   - Form fields auto-populate
   - User can edit if needed
   
4. **Save Expense**
   - Complete the form
   - Tap "Add Expense"
   - Expense is saved with receipt reference

### For Developers

To integrate with different OCR services:

1. **Google Vision API**:
   ```python
   from google.cloud import vision
   client = vision.ImageAnnotatorClient()
   response = client.text_detection(image)
   ```

2. **Azure Computer Vision**:
   ```python
   from azure.cognitiveservices.vision.computervision import ComputerVisionClient
   # Uses receipt OCR pre-built model
   ```

3. **Tesseract**:
   ```python
   import pytesseract
   text = pytesseract.image_to_string(image)
   ```

## Error Handling

The app handles several error scenarios:

1. **Camera Permission Denied**
   - User is informed via SnackBar
   - Gallery option still available

2. **Upload Failure**
   - Network error message displayed
   - User can retry
   - Previously captured image is preserved

3. **OCR Extraction Failure**
   - Server returns error
   - User is notified
   - Expense form can still be completed manually

## Dependencies

Added to `pubspec.yaml`:
```yaml
image_picker: ^1.0.7
camera: ^0.10.5
path_provider: ^2.1.1
```

## iOS Configuration

Add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan receipts</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to select receipt images</string>
```

## Android Configuration

Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## Future Enhancements

1. **Batch Upload**: Process multiple receipts
2. **Receipt Gallery**: Store and view receipt history
3. **Data Validation**: Verify extracted data accuracy
4. **Custom Categories**: Learn user's category preferences
5. **Receipt Editing Interface**: Edit OCR results before saving
6. **Email Receipts**: Auto-import from email
7. **Receipt Sharing**: Export and share receipts
8. **Subscription Tracking**: Identify recurring charges

## Troubleshooting

**Issue**: Camera permission denied
- **Solution**: Go to app settings and enable camera permission

**Issue**: Image upload fails
- **Solution**: Check internet connection and server availability

**Issue**: OCR results are inaccurate
- **Solution**: Ensure receipt is well-lit and in focus
- **Solution**: Try different image angle

**Issue**: Form fields don't auto-fill
- **Solution**: Check server response format matches expected JSON

## Testing

### Manual Testing Steps

1. Open Add Expense screen
2. Tap "Scan Receipt" button
3. Test both camera capture and gallery selection
4. Verify image preview works
5. Upload receipt and check for confirmation
6. Verify form auto-fill (if enabled on server)
7. Save expense and verify it's created

### Mock Server Response

For testing without a real OCR backend:

```dart
// In client.dart for testing
if (kDebugMode) {
  // Return mock OCR result
  return {
    'success': true,
    'extractedData': {
      'merchant': 'Sample Store',
      'amount': 25.50,
      'date': DateTime.now().toIso8601String(),
    }
  };
}
```
