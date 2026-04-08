public with sharing class IDValidationController {
    
    @AuraEnabled
    public static Map<String, Object> processIDSearch(String idNumber) {
        try {
            // 1. Decode Information
            Integer yearShort = Integer.valueOf(idNumber.substring(0, 2));
            Integer month = Integer.valueOf(idNumber.substring(2, 4));
            Integer day = Integer.valueOf(idNumber.substring(4, 6));
            Integer fullYear = (yearShort <= 26) ? 2000 + yearShort : 1900 + yearShort;
            Date dob = Date.newInstance(fullYear, month, day);
            
            String gender = (Integer.valueOf(idNumber.substring(6, 10)) < 5000) ? 'Female' : 'Male';
            Boolean isCitizen = Integer.valueOf(idNumber.substring(10, 11)) == 0;
            String citizenStatus = isCitizen ? 'SA Citizen' : 'Permanent Resident';

            // 2. API Callout (Must happen before DML)
            List<Object> holidays = fetchHolidays(fullYear);

            // 3. Store/Update Record and Increment Counter
            List<ID_Search_History__c> existing = [SELECT Id, Search_Count__c FROM ID_Search_History__c WHERE ID_Number__c = :idNumber LIMIT 1];
            
            ID_Search_History__c record = new ID_Search_History__c();
            record.ID_Number__c = idNumber;
            record.Name = idNumber; // Set record name to the ID
            record.Date_of_Birth__c = dob;
            record.Gender__c = gender;
            record.Is_Citizen__c = isCitizen;
            
            if (!existing.isEmpty()) {
                record.Id = existing[0].Id;
                record.Search_Count__c = existing[0].Search_Count__c + 1;
            } else {
                record.Search_Count__c = 1;
            }
            upsert record;

            return new Map<String, Object>{
                'dob' => dob.format(),
                'gender' => gender,
                'citizenStatus' => citizenStatus,
                'holidays' => holidays,
                'searchCount' => record.Search_Count__c
            };
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static List<Object> fetchHolidays(Integer year) {
        String apiKey = '24c5e86734eb44dc4a962826324a5546e74dc42f';
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://calendarific.com/api/v2/holidays?&api_key=' + apiKey + '&country=ZA&year=' + year);
        request.setMethod('GET');
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() == 200) {
            Map<String, Object> results = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
            Map<String, Object> resp = (Map<String, Object>)results.get('response');
            return (List<Object>)resp.get('holidays');
        }
        return new List<Object>();
    }
}