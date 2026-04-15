public with sharing class IDValidationController {
    
    @AuraEnabled
    public static Map<String, Object> processIDSearch(String idNumber) {
        // 1. Validation: Format and Checksum (User Story 2 & 3)
        if (String.isBlank(idNumber) || !Pattern.matches('^[0-9]{13}$', idNumber)) {
            throw new AuraHandledException('Invalid ID format. Please provide a 13-digit numeric ID.');
        }
        
        // Final backend safety check: Validate the Luhn checksum before saving to DB
        if (!validateLuhn(idNumber)) {
            throw new AuraHandledException('The ID number provided is mathematically invalid (Luhn check failed).');
        }

        try {
            // 2. Decode Information (User Story 3)
            Integer yearShort = Integer.valueOf(idNumber.substring(0, 2));
            Integer month = Integer.valueOf(idNumber.substring(2, 4));
            Integer day = Integer.valueOf(idNumber.substring(4, 6));
            
            // Dynamic Pivot: Use current year (2026) to determine century
            Integer currentYear = Date.today().year();
            Integer currentCenturyPivot = Integer.valueOf(String.valueOf(currentYear).substring(2, 4));
            Integer fullYear = (yearShort <= currentCenturyPivot) ? 2000 + yearShort : 1900 + yearShort;
            
            Date dob = Date.newInstance(fullYear, month, day);
            String gender = (Integer.valueOf(idNumber.substring(6, 10)) < 5000) ? 'Female' : 'Male';
            Boolean isCitizen = idNumber.substring(10, 11) == '0';

            // 3. API Callout (User Story 4)
            List<Map<String, String>> holidays = fetchHolidays(fullYear);

            // 4. Update/Store Search History Record (User Story 3)
            ID_Search_History__c record;
            List<ID_Search_History__c> existing = [
                SELECT Id, Search_Count__c 
                FROM ID_Search_History__c 
                WHERE ID_Number__c = :idNumber 
                LIMIT 1
            ];
            
            if (!existing.isEmpty()) {
                record = existing[0];
                record.Search_Count__c += 1;
            } else {
                record = new ID_Search_History__c(
                    ID_Number__c = idNumber,
                    Name = idNumber,
                    Search_Count__c = 1
                );
            }
            
            record.Date_of_Birth__c = dob;
            record.Gender__c = gender;
            record.Is_Citizen__c = isCitizen;
            
            upsert record;

            // 5. Return clean data to the LWC
            return new Map<String, Object>{
                'dob' => dob.format(),
                'gender' => gender,
                'citizenStatus' => isCitizen ? 'SA Citizen' : 'Permanent Resident',
                'holidays' => holidays,
                'searchCount' => record.Search_Count__c
            };

        } catch (Exception e) {
            throw new AuraHandledException('Server Error: ' + e.getMessage());
        }
    }

    /**
     * STEP A: Helper method with Debugging to find the 400 Error
     */
    private static List<Map<String, String>> fetchHolidays(Integer year) {
        String apiKey = '24c5e86734eb44dc4a962826324a5546e74dc42f';
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        
        // DEBUG STATEMENT FOR STEP A
        String endpoint = 'https://calendarific.com/api/v2/holidays?api_key=' + apiKey + '&country=ZA&year=' + year;
        System.debug('DEBUG - Calendarific URL: ' + endpoint);
        
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setTimeout(12000);
        
        HttpResponse response = http.send(request);
        List<Map<String, String>> cleanedHolidays = new List<Map<String, String>>();
        
        // STEP B: Handle non-200 responses to avoid parsing errors
        if (response.getStatusCode() == 200) {
            Map<String, Object> results = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
            Map<String, Object> resp = (Map<String, Object>)results.get('response');
            
            if (resp != null && resp.containsKey('holidays')) {
                List<Object> rawHolidays = (List<Object>)resp.get('holidays');
                for (Object obj : rawHolidays) {
                    Map<String, Object> h = (Map<String, Object>)obj;
                    Map<String, Object> d = (Map<String, Object>)h.get('date');
                    
                    Map<String, String> simplified = new Map<String, String>();
                    simplified.put('name', (String)h.get('name'));
                    simplified.put('iso', (String)d.get('iso'));
                    cleanedHolidays.add(simplified);
                }
            }
        } else {
            // This will show up in your Developer Console Logs
            System.debug('API FAILED. Status: ' + response.getStatusCode() + ' Body: ' + response.getBody());
        }
        
        return cleanedHolidays;
    }

    /**
     * Backend Luhn Validation (User Story 3 Requirement: Only valid IDs stored)
     */
    private static Boolean validateLuhn(String id) {
        Integer sum = 0;
        Boolean shouldDouble = false;
        for (Integer i = id.length() - 1; i >= 0; i--) {
            Integer digit = Integer.valueOf(id.substring(i, i + 1));
            if (shouldDouble) {
                digit *= 2;
                if (digit > 9) digit -= 9;
            }
            sum += digit;
            shouldDouble = !shouldDouble;
        }
        return Math.mod(sum, 10) == 0;
    }
}