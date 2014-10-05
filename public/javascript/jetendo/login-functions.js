
(function($, window, document, undefined){
	"use strict";
	function zIsLoggedIn(){
		var loggedIn=zGetCookie("ZLOGGEDIN");
		var d=zGetCookie("ZSESSIONEXPIREDATE");
		if(loggedIn === "1" && d !== ""){
			var n=new Date(d.toLocaleString()); 
			if(n < new Date()){
				zDeleteCookie("ZSESSIONEXPIREDATE");
				return false;
			}else{
				return true;
			}
		}else{
			return false;
		}
	}
	var zLoggedInTimeoutID=false;
	zArrDeferredFunctions.push(function(){
		zLoggedInTimeoutID=setInterval(function(){
			zLoggedIn=zIsLoggedIn();
		}, 1000);
	});

	var zLogin={
		autoLoginValue:-1,
		autoLoginCallback:0,
		devLogin:false,
		devLoginURL:"",
		loginErrorCallback:function(r){
			console.log("Login service temporarily unavailable. Try again later.");
			zLogin.enableLoginButtons();
		},
		enterPressed:false,
		lastKeyPressed:0,
		loginCallback:function(r){
			var json=eval('(' + r + ')');
			// supplement ip developer security with cookie to identify a single computer from the IP.
			if(typeof json.developer !== "undefined"){
				// cookie expires one year in future
				zSetCookie({key:"zdeveloper",value:json.developer,futureSeconds:31536000,enableSubdomains:true}); 
			}
			if(json.success){
				zLogin.zShowLoginError("Logging in...");
				var d1=window.parent.document.getElementById("zRepostForm");
				if(d1){
					setTimeout('window.parent.document.zRepostForm.submit();',5000);
					d1.submit();
				}
			}else{
				zLogin.zShowLoginError('<strong>'+json.errorMessage+'<\/strong>');
				zLogin.enableLoginButtons();
			}
			zLogin.enableLoginButtons();
		},
		disableLoginButtons:function(){
			document.getElementById("submitForm").disabled=true;
			document.getElementById("submitForm2").disabled=true;
		},
		enableLoginButtons:function(){
			document.getElementById("submitForm").disabled=false;
			document.getElementById("submitForm2").disabled=false;
		},
		zAjaxResetPasswordCallback:function(r){
			var json=eval('(' + r + ')');
			if(typeof json === "object"){
				if(json.success){
					zLogin.zShowLoginError("Reset password email sent. Click the link in the email to complete the process.");
				}else{
					zLogin.zShowLoginError(json.errorMessage);
				}
			}else{
				zLogin.zShowLoginError("The username provided is not a valid user.");
			}
			zLogin.enableLoginButtons();
		},
		zAjaxResetPassword:function(){
			var tempObj={};
			tempObj.id="zAjaxUserResetPassword";
			tempObj.url="/z/user/preference/update";
			if(document.getElementById('z_tmpusername2').value.length===""){
				zLogin.zShowLoginError("Email and the new password are required before clicking \"Reset Password\".");
				return;
			}
			if(document.getElementById('z_tmppassword2').value.length===""){
				zLogin.zShowLoginError("You must enter a new password before clicking \"Reset Password\"");
				return;
			}
			tempObj.postObj={
				k:"",
				e:document.getElementById('z_tmpusername2').value,
				user_password:document.getElementById('z_tmppassword2').value,
				submitPref:"Reset Password"
			};
			tempObj.method="post";
			tempObj.cache=false;
			tempObj.errorCallback=zLogin.loginErrorCallback;
			tempObj.callback=zLogin.zAjaxResetPasswordCallback;
			tempObj.ignoreOldRequests=true;
			zAjax(tempObj);	
			return false;
		},
		zShowLoginError:function(message){
			var d2=document.getElementById('statusDiv');
			if(d2){
				d2.style.display="block";
				d2.innerHTML='<span style="color:#900;">'+message+'<\/span>';
				document.getElementById("submitForm2").style.display="block";
				document.getElementById("submitForm").style.display="block";
			}
		},
		setAutoLogin:function(r){ 
			if (r===true){
				zLogin.autoLoginValue="1";
				zSetCookie({key:"zautologin",value:"1",futureSeconds:60,enableSubdomains:false}); 
			}else{
				zLogin.autoLoginValue="0";
				zSetCookie({key:"zautologin",value:"0",futureSeconds:60,enableSubdomains:false}); 
			}
			zLogin.autoLoginCallback();
		},
		autoLoginPrompt:function(callback){
			zSetCookie({key:"zautologin",value:"",futureSeconds:60,enableSubdomains:false}); 
			// Avoid calling the model window again during this login session
			if(zLogin.autoLoginValue===-1 && zGetCookie("zautologin") === ""){
				zLogin.autoLoginCallback=callback;
				var modalContent1='<div class="zmember-autologin-heading">Do you want to<br />login automatically<br />in the future?<\/div><div><a class="zmember-autologin-button" style="border:1px solid #000;" href="#" onclick="zLogin.setAutoLogin(true);zCloseModal();return false;">Yes<\/a>   <a class="zmember-autologin-button" href="#" onclick="zLogin.enterPressed=false;zLogin.setAutoLogin(false);zCloseModal();return false;">No<\/a><\/div>';
				zShowModal(modalContent1,{'disableClose':true,'width':Math.min(350, zWindowSize.width-50),'height':Math.min(250, zWindowSize.height-50),"maxWidth":350, "maxHeight":250});
				$(window).keypress(function(event){
					if(event.keyCode === 13){
						if(zLogin.lastKeyPressed===13){
							return;
						}
						if(zLogin.enterPressed){
							zLogin.enterPressedTwice=true;
						}
						zLogin.enterPressed=true;
						zLogin.lastKeyPressed=13; 
					}
				});
				$(window).bind("keyup", function(event){
					zLogin.lastKeyPressed=0;
					if(zLogin.enterPressedTwice && event.keyCode === 13){
						zLogin.setAutoLogin(true);
						zCloseModal();
					}
				});
				$("#zModalOverlayDiv").focus();
			}else{
				callback();
			}
		},
		autoLoginConfirm:function(){
			zLogin.autoLoginPrompt(zLogin.zAjaxSubmitLogin);
			return false;
		},
		zAjaxSubmitLogin:function(){
			var tempObj={};
			tempObj.id="zAjaxUserLogin"; 
			tempObj.url="/z/user/login/process";
			zLogin.zShowLoginError("Processing login credentials...");
			if(document.getElementById('z_tmpusername2').value.length==="" || document.getElementById('z_tmppassword2').value.length===""){
				zLogin.zShowLoginError("Email and password are required.");
				return;
			}
			tempObj.postObj={
				z_tmpusername2:document.getElementById('z_tmpusername2').value,
				z_tmppassword2:document.getElementById('z_tmppassword2').value,
				zIsMemberArea:document.getElementById('zIsMemberArea').value,
				zautologin:zLogin.autoLoginValue
			};
			tempObj.method="post";
			tempObj.cache=false;
			tempObj.errorCallback=zLogin.loginErrorCallback;
			tempObj.callback=zLogin.loginCallback;
			tempObj.ignoreOldRequests=true;
			zAjax(tempObj);	
			return false;
		},
		openidAutoConfirm:function(dev){
			zLogin.autoLoginPrompt(zLogin.zOpenidLogin);
		},
		openidAutoConfirm2:function(theLink){
			zLogin.devLoginURL=theLink;
			zLogin.autoLoginPrompt(zLogin.zOpenidLogin2);
		},
		zOpenidLogin2:function(){
			window.location.href=zLogin.devLoginURL;
		},
		zOpenidLogin3:function(devLoginURL){
			window.location.href=devLoginURL;
		},
		zOpenidLogin:function(dev){
			var d1=0;
			if(dev){
				d1=document.getElementById("openidhiddenurl2");
			}else{
				d1=document.getElementById("openidhiddenurl");
			}
			d2=document.getElementById("openidurl");
			zSetCookie({key:"zopenidurl",value:d2.value,futureSeconds:315360000,enableSubdomains:false}); 
			if(d2.value === "" || (d2.value.substr(0,7) !== "http://" && d2.value.substr(0,8) !== "https://")){
				alert('You must enter an OpenID Provider URL or click one of the Google / Yahoo login buttons.');
				return;
			}
			window.location.href=d2.value+d1.value;
			return;
		},
		checkIfPasswordsMatch:function(){
			var d1=document.getElementById("passwordPwd");
			var d2=document.getElementById("passwordPwd2");
			var d3=document.getElementById("passwordMatchBox");
			if(d1.value===""){
				return true;
			}else if(d1.value !== d2.value){
				d3.style.display="block";
				return false;
			}else{
				d3.style.display="none";
				return true;
			}
		},
		confirmToken:function(){
			var tempObj={};
			tempObj.id="zAjaxConfirmToken";
			tempObj.method="post";
			tempObj.cache=false;
			tempObj.errorCallback=zLogin.loginErrorCallback;
			tempObj.callback=zLogin.confirmTokenCallback;
			tempObj.ignoreOldRequests=true;
			tempObj.url="/z/user/login/confirmToken";
			
			if(typeof zLoginServerToken !== "undefined" && zLoginServerToken.loggedIn){
				tempObj.postObj={
					tempToken:zLoginServerToken.token
				};
				if(typeof zLoginServerToken.developer !== "undefined"){
					zSetCookie({key:"zdeveloper",value:zLoginServerToken.developer,futureSeconds:31536000,enableSubdomains:true}); 
				};
				zAjax(tempObj);	
				return false;
			}else if(typeof zLoginParentToken !== "undefined" && zLoginParentToken.loggedIn){
				if(typeof zLoginParentToken.developer !== "undefined"){
					zSetCookie({key:"zdeveloper",value:zLoginParentToken.developer,futureSeconds:31536000,enableSubdomains:true}); 
				};
				tempObj.postObj={
					tempToken:zLoginParentToken.token
				};
				zAjax(tempObj);	
				return false;
			}else{
				/*
				// show message that you can login to parent domain
				var d1=document.getElementById('loginFooterMessage');
				var d2='Global login available for your sites: ';
				var d3=false;
				if(typeof zLoginParentToken !== "undefined"){
					d3=true;
					d2+='<a href="'+zLoginParentToken.loginURL+'" target="_blank">Parent Site Manager Login</a>';
				}
				if(typeof zLoginServerToken !== "undefined"){
					// show message you can login to server manager
					if(d3){
						d2+' or ';
					}
					d2+='<a href="'+zLoginServerToken.loginURL+'" target="_blank">Server Manager Login</a>';
				}
				d1.innerHTML=d2;
				*/
			}
		},
		confirmTokenCallback:function(r){
			var json=eval('(' + r + ')');
			if(typeof json === "object"){
				if(json.success){
					// do the repost form
					zLogin.zShowLoginError("Logging in...");
					var d1=window.parent.document.getElementById("zRepostForm");
					if(d1){
						setTimeout('window.parent.document.zRepostForm.submit();',5000);
						d1.submit();
					}
				}
			}
		},
		init:function(){
			var d1=document.getElementById("z_tmpusername2");
			var d2=zGetCookie("zparentlogincheck");
			if((d2 === "" || typeof d1 !== "undefined") && window.location.href.toLowerCase().indexOf("zlogout=") === -1){
				zSetCookie({key:"zparentlogincheck",value:"1",futureSeconds:0,enableSubdomains:false}); 
				zLogin.confirmToken();
			}
		}
		
	};
	zArrDeferredFunctions.push(zLogin.init);
	window.zLogin=zLogin;
	window.zIsLoggedIn=zIsLoggedIn;
})(jQuery, window, document, "undefined"); 