package com.diabeticai.app.ui.care

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import com.diabeticai.app.databinding.FragmentPersonalizedCareBinding

class PersonalizedCareFragment : Fragment() {

    private var _binding: FragmentPersonalizedCareBinding? = null
    private val binding get() = _binding!!
    private val viewModel: CareViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentPersonalizedCareBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        viewModel.carePlan.observe(viewLifecycleOwner) { plan ->
            // Update Care Plan UI fields dynamically if needed
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
