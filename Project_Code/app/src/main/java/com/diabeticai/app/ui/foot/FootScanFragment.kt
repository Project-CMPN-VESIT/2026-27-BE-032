package com.diabeticai.app.ui.foot

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import com.diabeticai.app.databinding.FragmentFootUlcerBinding

class FootScanFragment : Fragment() {

    private var _binding: FragmentFootUlcerBinding? = null
    private val binding get() = _binding!!
    private val viewModel: FootScanViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentFootUlcerBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding.btnFootCamera.setOnClickListener {
            Toast.makeText(requireContext(), "Camera launched for Foot Scan", Toast.LENGTH_SHORT).show()
        }

        binding.btnFootGallery.setOnClickListener {
            Toast.makeText(requireContext(), "Gallery opened for image selection", Toast.LENGTH_SHORT).show()
        }

        binding.btnAnalyzeFoot.setOnClickListener {
            viewModel.runFootAnalysis()
        }

        viewModel.footScanResult.observe(viewLifecycleOwner) { result ->
            if (result != null) {
                binding.cardFootResult.visibility = View.VISIBLE
                binding.tvFootPrediction.text = result.predictionLabel
                binding.tvFootConfidence.text = "${result.confidencePercentage}%"
                Toast.makeText(requireContext(), "Foot Ulcer AI Analysis Complete!", Toast.LENGTH_SHORT).show()
            }
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
