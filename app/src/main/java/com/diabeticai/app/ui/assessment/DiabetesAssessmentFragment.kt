package com.diabeticai.app.ui.assessment

import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import com.diabeticai.app.data.model.RiskLevel
import com.diabeticai.app.databinding.FragmentDiabetesAssessmentBinding
import java.util.Locale

class DiabetesAssessmentFragment : Fragment() {

    private var _binding: FragmentDiabetesAssessmentBinding? = null
    private val binding get() = _binding!!
    private val viewModel: AssessmentViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentDiabetesAssessmentBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Live Auto BMI Calculation
        val bmiWatcher = object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                updateBmi()
            }
            override fun afterTextChanged(s: Editable?) {}
        }

        binding.etAssessmentHeight.addTextChangedListener(bmiWatcher)
        binding.etAssessmentWeight.addTextChangedListener(bmiWatcher)

        binding.btnAnalyzeAssessment.setOnClickListener {
            val glucose = binding.etAssessmentGlucose.text?.toString()?.toDoubleOrNull() ?: 95.0
            val hba1c = binding.etAssessmentHba1c.text?.toString()?.toDoubleOrNull() ?: 5.4

            viewModel.runAssessment(glucose, hba1c)
        }

        viewModel.assessmentResult.observe(viewLifecycleOwner) { result ->
            if (result != null) {
                binding.cardAssessmentResult.visibility = View.VISIBLE
                binding.tvResultBadge.text = result.predictionLabel.uppercase()
                binding.tvResultRiskPercent.text = String.format(Locale.getDefault(), "%.1f%%", result.riskPercentage)
                binding.tvResultConfidence.text = String.format(Locale.getDefault(), "%.1f%%", result.confidencePercentage)

                when (result.riskLevel) {
                    RiskLevel.HEALTHY -> {
                        binding.tvResultBadge.text = "HEALTHY"
                        binding.tvResultSummary.text = "Healthy - Low Risk. Metabolic parameters are within normal range."
                    }
                    RiskLevel.PREDIABETIC -> {
                        binding.tvResultBadge.text = "PREDIABETIC"
                        binding.tvResultSummary.text = "Prediabetic Risk Profile. Elevated glucose or HbA1c levels detected."
                    }
                    else -> {
                        binding.tvResultBadge.text = "DIABETIC"
                        binding.tvResultSummary.text = "High Diabetes Risk Detected. Please consult a healthcare professional."
                    }
                }

                Toast.makeText(requireContext(), "Assessment Complete!", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun updateBmi() {
        val h = binding.etAssessmentHeight.text?.toString()?.toDoubleOrNull() ?: 0.0
        val w = binding.etAssessmentWeight.text?.toString()?.toDoubleOrNull() ?: 0.0
        val bmi = viewModel.calculateBmi(h, w)
        if (bmi > 0) {
            binding.tvAssessmentBmi.text = String.format(Locale.getDefault(), "BMI: %.1f", bmi)
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
