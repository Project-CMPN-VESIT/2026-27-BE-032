package com.diabeticai.app.ui.dashboard

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.diabeticai.app.data.model.User
import com.diabeticai.app.data.repository.DiabeticRepository

class DashboardViewModel : ViewModel() {
    private val repository = DiabeticRepository()

    private val _userData = MutableLiveData<User>()
    val userData: LiveData<User> = _userData

    init {
        _userData.value = User(name = "Priya Sharma", email = "priya.sharma@example.com")
    }
}
