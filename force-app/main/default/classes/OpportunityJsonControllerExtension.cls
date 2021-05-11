public with sharing class OpportunityJsonControllerExtension {
    private ApexPages.StandardController controller;
    private String OpID;
    private String JSONData;
    private String standardTemplateName;
    private String imcTemplateName;

    public OpportunityJsonControllerExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        OpID = this.controller.getId();
    }

    //  05.01.2021 - Class Fields/Properties for display on page
    //  *************************************************************************************************************
    Public Pagereference Back(){
        return new Pagereference('/'+ OpID);
    }

    public String Template{get;set;}
    public String ContractName{get;set;}
    public String getJSONData(){return JSONData;}

    //  *************************************************************************************************************

    public string getStandardTemplate(){
        return standardTemplateName;
    }
    
    public List<SelectOption> getTemplates() {
        List<SelectOption> Templates = new List<SelectOption>();
        Templates.add(new SelectOption('K12-Template.dotx','Assessments'));
        Templates.add(new SelectOption('HED-Template.dotx','Higher Ed'));
        Templates.add(new SelectOption('IMC Subscription Agreement.dotx','IMC - Do not have a current SSS'));
        Templates.add(new SelectOption('IMC Rider.dotx','IMC - Have a current SSS'));
        Templates.add(new SelectOption('IMC Addendum.dotx','IMC - Have previous IMC agreement and a current SSS'));
        return Templates;
    }

    public List<SelectOption> getIMCTemplates() {
        List<SelectOption> imcTemplates = new List<SelectOption>();
        imcTemplates.add(new SelectOption('IMC Subscription Agreement.dotx','IMC - Do not have a current SSS'));
        imcTemplates.add(new SelectOption('IMC Rider.dotx','IMC - Have a current SSS'));
        imcTemplates.add(new SelectOption('IMC Addendum.dotx','IMC - Have previous IMC agreement and a current SSS'));
        return imcTemplates;
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
        /*
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
            gen.writeStringField('WordTemplate', Template); // 05.06.2021 - Explicitly selecting the Word template now
            gen.writeFieldName('Agreement');
            gen.writeStartObject();
                gen.writeStringField('AccountName', selOp.Account.Name);
                gen.writeStringField('ContractStartDate', selOp.Start_Date__c.format());
                gen.writeStringField('ContractEndDate', selOp.End_Date__c.format());
                
                /* *******************************************************************************************************************
                This value HAS to be a number (integer) because it becomes part of an enumeration in the web api
                05.05.2021 - Considering using Custom Settings in Salesforce instead of storing a template value in products
                *  I'll also need to figure out how Custom Settings and this code will work
                **********************************************************************************************************************/
                // gen.writeNumberField('InstitutionType', templateChoice);
                /* *******************************************************************************************************************/

                gen.writeStringField('TotalPrice', selOp.Amount.format()); // ALL numbers from Salesforce are converted to a string. format() gives me the "," for currency
                
                /*  05.10.2021 Want error trapping here in case signaatory is not entered.
                */
                for (OpportunityContactRole contact : OpContacts) {
                    if (contact.Role=='Signatory') {
                        gen.writeStringField('ClientSignatory', contact.contact.Name);
                        gen.writeStringField('ClientTitle', contact.contact.Title);  
                    }
                }

                /* 04.01.2021 - I need to figure out how to add users and pull this info from there!
                *  05.10.2021 - Either from the form where the contact is generated or opportunity
                *  also, just add Signatory_Title__c
                */
                gen.writeStringField('Signatory', selOp.Signatory__c);
                gen.writeStringField('SignatoryTitle', selOp.Signatory_Title__c);
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

            /* 05.10.2021 Interest in My College, doesn't have quotes, so
            how do I skip this? */
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

        // Returning Blob data
        //SaveContractToOpportunity(OpID, SendJSON(JSONData));
        // 05.04.2021 - Can I dump the blob before I return the page??
        return null;
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
        Signatory_Title__c,
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
            AND OpportunityContactRole.OpportunityId = :OpID
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
    //  04.23.2021 This SOQL needs to include any discounts that may be added
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

    /* 04.22.2021 - Took this from SFSoleSourceLetter. Need to REALLY look at this.
    *  04.23.2021 - This WORKS!! No need to modify!
    *  Okay, I need the ASP.NET Core RESTful web api to return a response so this 
    *  code may need to change some.
    */
    public Blob SendJSON(string JSONData){
        string WebApiResponse;
        Blob contractWordDoc;

        HttpRequest req = new HttpRequest();
        string Url = 'https://cbgeneratecontracts.azurewebsites.net/DocumentGeneration/Agreement';
            
        req.setHeader('Content-Type', 'application/json');
        req.setEndpoint(Url);
        req.setMethod('POST');
        req.setBody(JSONData);
        req.setTimeout(20000);
                        
        Http http = new Http();
        HttpResponse res = http.send(req);

        // Return Response header values
        this.ContractName = res.getHeader('ContractName');
            
        contractWordDoc = res.getBodyAsBlob();
        return contractWordDoc;
    }

    public void SaveContractToOpportunity(string parentIDOp, blob file)
    {
        /*   04.24.2021 Adding ability to save newly created contract in Salesforce 
        *  UPDATE 05.01.2021 This code WORKS!! It uploads a file that I specify below
        *  using versionData, title & pathOnClient
        */
        ContentVersion v = new ContentVersion();
        v.title = this.ContractName;
        v.pathOnClient = '/' + this.ContractName;
        v.IsMajorVersion=true; // Saw this in an example. Maybe I need this?
        v.versionData = file;
        v.FirstPublishLocationId=parentIDOp; // Is THIS where I connect the uploaded document to my opportunity?? 05.04.2021 - YES!
        insert v;

        /* Do I need to explicitly create a new ContentDocumentLink object in order to associate this document with the opportunity?
        *  OR 
        *  Does assigning an opportunity ID to FirstPublishLocation do it for me?
        */
    }
}
