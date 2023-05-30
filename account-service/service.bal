import ballerina/http;
import ballerina/mime;
import ballerina/io;
import ballerina/jwt;
import ballerina/uuid;

configurable string clientID = ?;
configurable string clientSecret = ?;
configurable string hostname = ?;
configurable string orgId = ?;

type Token record {
    string access_token;
    string token_type;
    string expires_in;
};

type AccountDetails record {
    string AccountID;
    string AccountType;
    decimal AvailableBalance;
};

type AccountResponse record {
    AccountRec AcctRec;

};

type AccountRec record {
    AccountKeys AcctKeys;
    DepositInfo DepositAcctInfo;
};

type AccountKeys record {
    string AcctId;
};

type DepositInfo record {
    string Desc;
    AccountBalance[] AcctBal;
};

type AccountBalance record {
    string BalType;
    CurrentAmount CurAmt;

};

type CurrentAmount record {
    decimal Amt;
};

service / on new http:Listener(9090) {
    resource function get accountDetails() returns AccountDetails|error? {
        Token authToken = check getAccessToken();
        [jwt:Header, jwt:Payload] [header, payload] = check jwt:decode(authToken.access_token);
        io:println("Header: ", header);
        io:println("Payload: ", payload);

        http:Request req = check getRequestWithHeaders(authToken);
        req.setJsonPayload({
            "AcctSel": {
                "AcctKeys": {
                    "AcctId": "5041733",
                    "AcctType": "DDA"
                }
            }
        });
        http:Client reqClient = check new (hostname);
        json res = check reqClient->/banking/efx/v1/acctservice/acctmgmt/accounts/secured.post(req);
        AccountResponse accRes = check res.cloneWithType(AccountResponse);
        AccountDetails accDetails = transform(accRes);
        return accDetails;
    }
}

function getRequestWithHeaders(Token token) returns http:Request|error {
    http:Request req = new;
    req.setHeader("Authorization", "Bearer " + token.access_token);
    json efxHeader = {
        "OrganizationId": orgId,
        "TrnId": uuid:createType4AsString()
    };
    req.setHeader("EfxHeader", efxHeader.toString());
    req.setHeader("Host", hostname);
    req.setHeader("Accept", "application/json");
    return req;
}

function getAccessToken() returns Token|error {
    http:Request tokenReq = new;
    tokenReq.setTextPayload("grant_type=client_credentials");
    tokenReq.setHeader(mime:CONTENT_TYPE, mime:APPLICATION_FORM_URLENCODED);
    http:Client req = check new (hostname,
        auth = {
            username: clientID,
            password: clientSecret
        }
    );
    json tokenRes = check req->post("/fts-apim/oauth2/v2", tokenReq);
    Token token = check tokenRes.cloneWithType(Token);
    return token;
}

function getAvailableCash(AccountBalance[] accbal) returns decimal {
    foreach AccountBalance bal in accbal {
        if bal.BalType == "AvailCash" {
            return bal.CurAmt.Amt;
        }
    }
    return -1.0;
}

function transform(AccountResponse accountResponse) returns AccountDetails => {
    AccountID: accountResponse.AcctRec.AcctKeys.AcctId,
    AccountType: accountResponse.AcctRec.DepositAcctInfo.Desc,
    AvailableBalance: getAvailableCash(accountResponse.AcctRec.DepositAcctInfo.AcctBal)
};
