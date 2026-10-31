package com.diabeticai.app.ui.eye

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import com.diabeticai.app.databinding.FragmentRetinaBinding

class EyeScanFragment : Fragment() {

    private var _binding: FragmentRetinaBinding? = null
    private val binding get() = _binding!!
    private val viewModel: EyeScanViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentRetinaBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding.btnRetinaCamera.setOnClickListener {
            Toast.makeText(requireContext(), "Camera launched for Retinal Scan", Toast.LENGTH_SHORT).show()
        }

        binding.btnRetinaGallery.setOnClickListener {
            Toast.makeText(requireContext(), "Gallery opened for Fundus image selection", Toast.LENGTH_SHORT).show()
        }

        binding.btnAnalyzeRetina.setOnClickListener {
            viewModel.runRetinaAnalysis()
        }

        viewModel.retinaResult.observe(viewLifecycleOwner) { result ->
            if (result != null) {
                binding.cardRetinaResult.visibility = View.VISIBLE
                binding.tvRetinaPrediction.text = result.predictionLabel
                binding.tvRetinaConfidence.text = "${result.confidencePercentage}%"
                Toast.makeText(requireContext(), "Retina AI Analysis Complete!", Toast.LENGTH_SHORT).show()
            }
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
