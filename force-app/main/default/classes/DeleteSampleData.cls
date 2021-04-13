public with sharing class DeleteSampleData {
    public DeleteSampleData() {
    }

    public void DeleteNullPricebookEntries(){
        PricebookEntry[] pe = [SELECT Pricebook2.Name
        FROM PricebookEntry
        WHERE Pricebook2.Name = NULL];

        try {
            delete pe;
        } catch (DmlException e) {
            e.getMessage();
        }
    }
}
