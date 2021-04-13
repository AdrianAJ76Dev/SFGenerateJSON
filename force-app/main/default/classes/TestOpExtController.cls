@isTest(SeeAllData=true)
public with sharing class TestOpExtController {
    private Opportunity Op;

    public TestOpExtController() {

    }

    @IsTest(SeeAllData=true)
    static void TestGenerateSFJSON(){
        Opportunity selOp;

        //  There's only 1 Opportunity so I don't need the ID to retrieve the right opportunity
        selOp = [SELECT 
        Account.Name,
        Start_Date__c,
        End_Date__c,
        Signatory__c,
        CloseDate,
        Amount,
        Account.Type
        FROM Opportunity];
       
        ApexPages.StandardController sc = new ApexPages.StandardController(selOp);
        OpportunityJsonControllerExtension OpJsonExt = new OpportunityJsonControllerExtension(sc);

        //  Invoke the routines here?
        OpJsonExt.GenerateSFJSON();
        OpJsonExt.getOpportunityJson();
    }
}
