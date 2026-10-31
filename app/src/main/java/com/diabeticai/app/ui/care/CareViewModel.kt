package com.diabeticai.app.ui.care

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.diabeticai.app.data.model.CarePlan
import com.diabeticai.app.data.model.RiskLevel
import com.diabeticai.app.data.repository.DiabeticRepository

class CareViewModel : ViewModel() {
    private val repository = DiabeticRepository()

    private val _carePlan = MutableLiveData<CarePlan>()
    val carePlan: LiveData<CarePlan> = _carePlan

    init {
        _carePlan.value = repository.getPersonalizedCarePlan(RiskLevel.HEALTHY)
    }

    fun loadCarePlanForLevel(level: RiskLevel) {
        _carePlan.value = repository.getPersonalizedCarePlan(level)
    }
}
