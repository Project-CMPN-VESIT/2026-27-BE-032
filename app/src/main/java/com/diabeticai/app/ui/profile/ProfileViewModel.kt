package com.diabeticai.app.ui.profile

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.diabeticai.app.data.model.User

class ProfileViewModel : ViewModel() {
    private val _userProfile = MutableLiveData<User>()
    val userProfile: LiveData<User> = _userProfile

    init {
        _userProfile.value = User(name = "Priya Sharma", email = "priya.sharma@example.com")
    }

    fun logout() {
        _userProfile.value = User(isLoggedIn = false)
    }
}
