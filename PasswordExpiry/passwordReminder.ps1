<#	
	.NOTES
	===========================================================================
	 Created on:   	3/27/2018 7:37 PM
	 Created by:   	Bradley Wyatt
	 Version: 	    1.0.0
	 Notes:
	The variables you should change are the SMTP Host, From Email and Expireindays. I suggest keeping the DirPath
	SMTPHOST: The smtp host it will use to send mail
	FromEmail: Who the script will send the e-mail from
	ExpireInDays: Amount of days before a password is set to expire it will look for, in my example I have 7. Any password that will expire in 7 days or less will start sending an email notification 

	Run the script manually first as it will ask for credentials to send email and then safely store them for future use.
	===========================================================================
	.DESCRIPTION
		This script will send an e-mail notification to users where their password is set to expire soon. It includes step by step directions for them to 
		change it on their own.

		It will look for the users e-mail address in the emailaddress attribute and if it's empty it will use the proxyaddress attribute as a fail back. 

		The script will log each run at $DirPath\log.txt

    script need ActiveDirectory-Powershell tools  install => Enable-WindowsOptionalFeature -FeatureName ActiveDirectory-Powershell -Online -All
#>

#VARs

#SMTP Host
$SMTPHost = "icewaterengineering-com0i1c.mail.protection.outlook.com"

#Who is the e-mail from
$FromEmail = "service_informatique_ice@ice-wm.com"

#Password expiry days
$expireindays = 14

#Program File Path
$DirPath = "D:\Automation\PasswordExpiry"

$Date = Get-Date

#Check if program dir is present
$DirPathCheck = Test-Path -Path $DirPath
If (!($DirPathCheck))
{
	Try
	{
		#If not present then create the dir
		New-Item -ItemType Directory $DirPath -Force
	}
	Catch
	{
		$_ | Out-File ($DirPath + "\" + "Log.txt") -Append
	}
}


#CredObj path
$CredObj = ($DirPath + "\" + "EmailExpiry.cred")

#Check if CredObj is present
$CredObjCheck = Test-Path -Path $CredObj
If (!($CredObjCheck))
{
	"$Date - INFO: creating cred object" | Out-File ($DirPath + "\" + "Log.txt") -Append
	#If not present get office 365 cred to save and store
	$Credential = Get-Credential -Message "Please enter your Office 365 credential that you will use to send e-mail from $FromEmail. If you are not using the account $FromEmail make sure this account has 'Send As' rights on $FromEmail."
	#Export cred obj
	$Credential | Export-CliXml -Path $CredObj
}

Write-Host "Importing Cred object..." -ForegroundColor Yellow
$Cred = (Import-CliXml -Path $CredObj)


# Get Users From AD who are Enabled, Passwords Expire and are Not Currently Expired
"$Date - INFO: Importing AD Module" | Out-File ($DirPath + "\" + "Log.txt") -Append
Import-Module ActiveDirectory
"$Date - INFO: Getting users" | Out-File ($DirPath + "\" + "Log.txt") -Append
$users = Get-Aduser -properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress -filter { (Enabled -eq 'True') -and (PasswordNeverExpires -eq 'False') } | Where-Object { $_.PasswordExpired -eq $False }

$maxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge
$qteUsers= @($users).Count

Write-Host "Qt� de comptes concern�s : $qteUsers" -ForegroundColor White
 "-------------------   Qt� de comptes concern�s : $qteUsers   ------------------" | Out-File ($DirPath + "\" + "Log.txt") -Append
# Process Each User for Password Expiry
foreach ($user in $users)
{
	$Name = (Get-ADUser $user | ForEach-Object { $_.Name })
    Write-Host "---------------------------" -ForegroundColor White
	Write-Host "Working on $Name..." -ForegroundColor White
	Write-Host "Getting e-mail address for $Name..." -ForegroundColor Yellow
	$emailaddress = $user.emailaddress
	If (!($emailaddress))
	{
		Write-Host "$Name has no E-Mail address listed, looking at their proxyaddresses attribute..." -ForegroundColor Red
		Try
		{
			$emailaddress = (Get-ADUser $user -Properties proxyaddresses | Select-Object -ExpandProperty proxyaddresses | Where-Object { $_ -cmatch '^SMTP' }).Trim("SMTP:")
		}
		Catch
		{
			$_ | Out-File ($DirPath + "\" + "Log.txt") -Append
		}
		If (!($emailaddress))
		{
			Write-Host "$Name has no email addresses to send an e-mail to!" -ForegroundColor Red
			#Don't continue on as we can't email $Null, but if there is an e-mail found it will email that address
			"$Date - WARNING: No email found for $Name" | Out-File ($DirPath + "\" + "Log.txt") -Append
		}	
	}
	#Get Password last set date
	$passwordSetDate = (Get-ADUser $user -properties * | ForEach-Object { $_.PasswordLastSet })

	#Check for Fine Grained Passwords
	$PasswordPol = (Get-ADUserResultantPasswordPolicy $user)
	if (($PasswordPol) -ne $null)
	{
		$maxPasswordAge = ($PasswordPol).MaxPasswordAge
	}
	
	$expireson = $passwordsetdate + $maxPasswordAge
	$today = (get-date)
	#Gets the count on how many days until the password expires and stores it in the $daystoexpire var
	$daystoexpire = (New-TimeSpan -Start $today -End $Expireson).Days
	
	If (($daystoexpire -ge "0") -and ($daystoexpire -lt $expireindays))
	{
		"$Date - INFO: Sending expiry notice email to $Name" | Out-File ($DirPath + "\" + "Log.txt") -Append
		Write-Host "Sending Password expiry email to $name" -ForegroundColor Yellow
		
		$SmtpClient = new-object system.net.mail.smtpClient
		$MailMessage = New-Object system.net.mail.mailmessage
		
		#Who is the e-mail sent from
		$mailmessage.From = $FromEmail

		#SMTP server to send email
		$SmtpClient.Host = $SMTPHost

		#SMTP SSL
		$SMTPClient.EnableSsl = $true

		#SMTP credentials
		$SMTPClient.Credentials = $cred

		#Send e-mail to the users email
		$mailmessage.To.add("$emailaddress")

		#Email subject
		$mailmessage.Subject = "Votre mot de passe expirera dans $daystoexpire jours / Your password will expire $daystoexpire days"

		#Notification email on delivery / failure
		$MailMessage.DeliveryNotificationOptions = ("onSuccess", "onFailure")

		#Send e-mail with high priority
		$MailMessage.Priority = "High"
		$mailmessage.Body =
		"Cher(e) $Name,
Le mot de passe utilis� pour se connecter � Windows arrive � expiration dans $daystoexpire jours.
Merci de penser � le changer d�s que possible.

La proc�dure de changement du mot de passe est la suivante:
1. Depuis la session Windows 
	a.	Le client VPN Sophos doit �tre mont� au pr�alable, si le pc n'est pas sur le r�seau d'ICE. 
	b.	Ouvrir sa session comme d'habitude et s'assurer d'�tre connect� � Internet.
	c.	Pressez sur les touches Ctrl-Alt-Del simultanement and cliquez sur ""Modifier un mot de passe"".
	d.	Saisissez l'ancien mot de passe et d�finissez le nouveau en respectant les contraintes de complexit� d�crites plus bas.
	e.	Appuyez sur OK pour valider la modification. 

Le nouveau mot de passe doit r�pondre aux exigences minimales �nonc�es dans notre politique d'entreprise, notamment�:
	1. Il doit comporter au moins 9 caract�res.
	2. Il doit contenir au moins un caract�re parmi 3 des 4 groupes de caract�res suivants :
		a. Lettres majuscules (A-Z)
		b. Lettres minuscules (a-z)
		c. Chiffres (0-9)
		d. Symboles (!@#$%^&*...)
	3. Il ne peut correspondre � aucun de vos 24 derniers mots de passe.
	4. Il ne peut pas contenir de caract�res correspondant � 3 caract�res cons�cutifs ou plus de votre nom d'utilisateur.
	5. Vous ne pouvez pas changer votre mot de passe plus d'une fois par p�riode de 24 heures.

Si vous avez des questions, vous pouvez contacter le service informatique � l'adresse support-it@ice-wm.com

----------------------------------------------------------------------------------------------------------------------------

Dear $Name,
Your Domain password will expire in $daystoexpire days. Please change it as soon as possible.

To change your password, follow the method below:

1. On your Windows computer
	a.	If you are not in the office, logon and connect to VPN. 
	b.	Log onto your computer as usual and make sure you are connected to the internet.
	c.	Press Ctrl-Alt-Del and click on ""Change Password"".
	d.	Fill in your old password and set a new password.  See the password requirements below.
	e.	Press OK to return to your desktop. 

The new password must meet the minimum requirements set forth in our corporate policies including:
	1.	It must be at least 9 characters long.
	2.	It must contain at least one character from 3 of the 4 following groups of characters:
		a.  Uppercase letters (A-Z)
		b.  Lowercase letters (a-z)
		c.  Numbers (0-9)
		d.  Symbols (!@#$%^&*...)
	3.	It cannot match any of your past 5 passwords.
	4.	It cannot contain characters which match 3 or more consecutive characters of your username.
	5.	You cannot change your password more often than once in a 24 hour period.

If you have any questions please contact our IT Support at support-it@ice-wm.com"

		Write-Host "Sending E-mail to $emailaddress..." -ForegroundColor Green
		Try
		{
			$smtpclient.Send($mailmessage)
		}
		Catch
		{
			$_ | Out-File ($DirPath + "\" + "Log.txt") -Append
		}
	}
	Else
	{
		"$Date - INFO: Password for $Name not expiring for $daystoexpire days" | Out-File ($DirPath + "\" + "Log.txt") -Append
		Write-Host "Password for $Name does not expire for $daystoexpire days" -ForegroundColor White
	}
}
