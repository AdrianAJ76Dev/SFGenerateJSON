public with sharing class OpportunityJsonControllerExtension {
    private ApexPages.StandardController controller;
    private String OpID;
    private string JSONData;
    private Decimal templateChoice;


    public OpportunityJsonControllerExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        OpID = this.controller.getId();
    }

    Public Pagereference Back(){
        return new Pagereference('/'+ OpID);
    }

    public Decimal getTemplateChoice()
    {
        templateChoice = getTemplateChoiceRec()[0].Contract_Template_Choice__c;
        return templateChoice;
    }

    public String getOpportunityJson()
    {
        return JSONData;
    }
    
    public Pagereference GenerateSFJSON()
    {
        /*  Adrian A. Jones
        *   03.30.2021
        *   04.01.2021 - Changed from building individual JSON objects 
        *   to building 1 object that contains the rest.
        */
        // Salesforce Object declarations
        Opportunity selOp;
        List<OpportunityContactRole> OpContacts;

        // 04.13.2021 Take a look at sorting in the List<> Class
        List<OpportunityLineItem> ContractRiders;
        List<OpportunityLineItem> OpBudgetSchedule;
 

        // SOQL in functions to return data to SObjects
        selOp = GetSFData_Opportunity();
        OpContacts = GetSFData_OpContacts();
        ContractRiders = GetSFData_Riders();
        OpBudgetSchedule = GetSFData_BudgetSchedule();

        JSONGenerator gen;

        // Institution Type is exported as a number instead of a string
        /* Integer institutionType;
        switch on selOp.Account.Type {
            when 'K12 Organization' {
                institutionType=0;
            }
            when 'Higher Ed Organization' {
                institutionType=1;
            }
        }
        */

        gen = JSON.createGenerator(true);

        // Start primary JSON object that encapsulates everything!
        gen.writeStartObject();
            // Create the Agreement JSON
            gen.writeFieldName('Agreement');
            gen.writeStartObject();
                gen.writeStringField('AccountName', selOp.Account.Name);
                gen.writeStringField('ContractStartDate', selOp.Start_Date__c.format());
                gen.writeStringField('ContractEndDate', selOp.End_Date__c.format());
                gen.writeNumberField('InstitutionType', templateChoice); //This value HAS to be a number (integer) because it becomes part of an enumeration in the web api
                gen.writeStringField('TotalPrice', selOp.Amount.format()); // ALL numbers from Salesforce are converted to a string. format() gives me the "," for currency
                
                /*  04.01.2021 - Cheating here Hardcoding values!!! 
                *   Must figure out how to pull the contact with signatory role here!!
                *   Right now, I pull contact values below and there is more than one!
                *   gen.writeStringField('ClientSignatory', 'Bullwinkle J. Moose');
                *   gen.writeStringField('ClientTitle', 'Scholar/Magician');
                */
                for (OpportunityContactRole contact : OpContacts) {
                    if (contact.Role=='Signatory') {
                        gen.writeStringField('ClientSignatory', contact.contact.Name);
                        gen.writeStringField('ClientTitle', contact.contact.Title);                        
                    }
                }

                // 04.01.2021 - I need to figure out how to add users and pull this info from there!
                gen.writeStringField('Signatory', selOp.Signatory__c);
                // 04.01.2021 - Cheating here. Hardcoding value!!
                gen.writeStringField('SignatoryTitle', 'Director of College Connections');
            gen.writeEndObject();

            // Create the Contacts JSON
            String opRoleContact;
            // Seriously consider changing the var contact to contactRole or something else
            for (OpportunityContactRole contact : OpContacts) {
                switch on contact.Role {
                    when 'Signatory' {
                        opRoleContact='PrimaryContact';
                    }
                    when 'Technical Support' {
                        opRoleContact='TechnicalSupport';                    
                    }
                    when 'Invoice and Billing' {
                        opRoleContact='InvoiceBilling';                                        
                    }
                }

                // 03-31-2021 Noticed that if the field in Salesforce is empty, any of these can fail. I need to handle NULL values
                gen.writeFieldName(opRoleContact);
                gen.writeStartObject();
                    gen.writeStringField('FirstName', contact.contact.FirstName);
                    gen.writeStringField('LastName', contact.contact.LastName);
                    gen.writeStringField('Title', contact.contact.Title);
                    gen.writeStringField('MailingStreet', contact.contact.MailingStreet);
                    gen.writeStringField('MailingCity', contact.contact.MailingCity);
                    gen.writeStringField('MailingState', contact.contact.MailingState);
                    gen.writeStringField('MailingPostalCode', contact.contact.MailingPostalCode);
                    gen.writeStringField('Phone', contact.contact.Phone);
                    gen.writeStringField('Email', contact.contact.Email);
                gen.writeEndObject();                
            }

            // Create the Riders JSON
            gen.writeFieldName('AgreementRiders');
            gen.writeStartArray();
                for (OpportunityLineItem rider : ContractRiders) {
                    gen.writeStartObject();
                        gen.writeStringField('ProductName', rider.Product2.Name);
                    gen.writeEndObject();
                }
            gen.writeEndArray();

            // Create the Budget Schedule JSON
            gen.writeFieldName('AgreementQuote');
            gen.writeStartObject();
                gen.writeFieldName('LineItems');
                gen.writeStartArray();
                    for (OpportunityLineItem BudgetItem : OpBudgetSchedule) {
                        gen.writeStartObject();
                            gen.writeStringField('ProductName', BudgetItem.Product2.Name);
                            gen.writeStringField('StartDate', BudgetItem.Start_Date__c.format());
                            gen.writeStringField('EndDate', BudgetItem.End_Date__c.format());
                            gen.writeStringField('Quantity', BudgetItem.Quantity.format());
                            gen.writeStringField('TotalCost', BudgetItem.TotalPrice.format());
                        gen.writeEndObject();
                    }                
                gen.writeEndArray();
        gen.writeEndObject();

        JSONData=gen.getAsString();

        return null;
    }

    private List<OpportunityLineItem> getTemplateChoiceRec()
    {
        List<OpportunityLineItem> templateChoiceRec;
        
        templateChoiceRec = [SELECT
        Contract_Template_Choice__c
        FROM OpportunityLineItem
        WHERE OpportunityLineItem.OpportunityId = :OpID
        LIMIT 1];

        return templateChoiceRec;
    }

    /*  Below is the SOQL needed to retrieve the data to be transformed into JSON
    *   Adrian A. Jones
    *   04.02.2021
    */
    // SOQL for getting the Main opportunity field data
    private Opportunity GetSFData_Opportunity()
    {
        Opportunity selOp;

        selOp =[SELECT 
        Account.Name,
        Start_Date__c,
        End_Date__c,
        Signatory__c,
        CloseDate,
        Amount,
        Account.Type
        FROM Opportunity
        WHERE Opportunity.Id=:OpID];

        return selOp;
    }
    
    // SOQL for getting the needed contacts field data
    private List<OpportunityContactRole> GetSFData_OpContacts()
    {
        List<OpportunityContactRole> OpContacts;

        OpContacts = [
            SELECT 
            IsPrimary,
            Role,
            Contact.FirstName,
            Contact.LastName,
            Contact.Name,
            Contact.Title,
            Contact.MailingStreet,
            Contact.MailingCity,
            Contact.MailingState,
            Contact.MailingPostalCode,
            Contact.MailingCountry,
            Contact.Phone,
            Contact.Email
            FROM OpportunityContactRole
            WHERE (Role='Signatory' OR Role ='Technical Support' OR Role = 'Invoice and Billing')
        ];

        return OpContacts;
    }
    
    //  SOQL for getting product names which designate the riders
    private List<OpportunityLineItem> GetSFData_Riders()
    {
        List<OpportunityLineItem> ContractRiders;

        // 04.14.2021 See if I can control sorting to match user sorting on the opportunity
        ContractRiders = [SELECT
        Product2.Name,
        Product2.Family
        FROM OpportunityLineItem
        WHERE OpportunityLineItem.OpportunityId = :OpID];
            
        return ContractRiders;
    }

    //  SOQL for getting what goes in the Budget Schedule
    private List<OpportunityLineItem> GetSFData_BudgetSchedule()
    {
        List<OpportunityLineItem> OpBudgetSchedule;

        OpBudgetSchedule = [SELECT 
        Product2.Name,
        Start_Date__c,
        End_Date__c,
        Quantity, 
        TotalPrice
        FROM OpportunityLineItem
        WHERE OpportunityLineItem.OpportunityId = :OpID];
            
        return OpBudgetSchedule;
    }
}
