package com.diabeticai.app.ui.history

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.diabeticai.app.data.model.PredictionResult
import com.diabeticai.app.data.repository.DiabeticRepository

class HistoryViewModel : ViewModel() {
    private val repository = DiabeticRepository()

    private val _historyList = MutableLiveData<List<PredictionResult>>()
    val historyList: LiveData<List<PredictionResult>> = _historyList

    init {
        _historyList.value = repository.getPredictionHistory()
    }
}
