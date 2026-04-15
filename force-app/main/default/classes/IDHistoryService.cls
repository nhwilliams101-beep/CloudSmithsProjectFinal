/**
 * SERVICE LAYER
 * This class is responsible for handling all interactions with the ID_Search_History__c object
 */
public without sharing class IDHistoryService {
    
    public static void upsertHistoryRecord(ID_Search_History__c record) {
        if (record != null) {
            // Upsert handles both creating new records and updating existing ones
            upsert record;
        }
    }
}