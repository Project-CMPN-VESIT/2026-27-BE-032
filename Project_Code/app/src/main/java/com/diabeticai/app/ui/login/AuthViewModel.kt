package com.diabeticai.app.ui.login

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel

class AuthViewModel : ViewModel() {

    private val _loginState = MutableLiveData<Boolean>()
    val loginState: LiveData<Boolean> = _loginState

    fun login(email: String, pass: String) {
        // Validate and complete login
        _loginState.value = email.isNotEmpty() && pass.isNotEmpty()
    }

    fun register(name: String, email: String, pass: String) {
        _loginState.value = name.isNotEmpty() && email.isNotEmpty() && pass.isNotEmpty()
    }
}
