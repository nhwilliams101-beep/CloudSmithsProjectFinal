/**
 * SERVICE LAYER
 * This class runs in "System Mode" to allow Guest Users to 
 * increment the search counter on existing records.
 */
public without sharing class IDHistoryService {
    
    public static void upsertHistoryRecord(ID_Search_History__c record) {
        if (record != null) {
            // Upsert handles both creating new records and updating existing ones
            upsert record;
        }
    }
}